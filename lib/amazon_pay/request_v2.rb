require 'net/http'
require 'securerandom'
require 'cgi/util'
require 'openssl'

module AmazonPay
  class RequestV2
    MAX_RETRIES = 3

    METHOD_TYPES = {
      get: Net::HTTP::Get,
      post: Net::HTTP::Post,
      patch: Net::HTTP::Patch,
      delete: Net::HTTP::Delete,
    }

    API_SERVICE_URL = {
      'eu' => 'pay-api.amazon.eu',
      'de' => 'pay-api.amazon.eu',
      'uk' => 'pay-api.amazon.eu',
      'us' => 'pay-api.amazon.com',
      'na' => 'pay-api.amazon.com',
      'jp' => 'pay-api.amazon.jp',
    }

    HASH_ALGORITHM = "SHA256"
    AMAZON_SIGNATURE_ALGORITH = "AMZN-PAY-RSASSA-PSS"

    def initialize(
          url_fragment,
          payload:,
          public_key_id:,
          headers:,
          method: :post,
          private_pem_path: nil,
          region: 'JP',
          sandbox: true,
          proxy_addr: :ENV,
          proxy_port: nil,
          proxy_user: nil,
          proxy_pass: nil,
          log_enabled: nil,
          log_file_name: nil,
          log_level: nil
        )

      @url_fragment = url_fragment
      @public_key_id = public_key_id
      private_pem_path ||= 'private.pem'
      @private_pem = File.read(private_pem_path)
      @region = region
      @sandbox = sandbox ? 'sandbox' : 'live'

      @method = method
      @payload = payload || ""
      @headers = headers || Hash.new

      @proxy_addr = proxy_addr
      @proxy_port = proxy_port
      @proxy_user = proxy_user
      @proxy_pass = proxy_pass

      @log_enabled = log_enabled
      @logger = AmazonPay::LogInitializer.new(log_file_name, log_level).create_logger if @log_enabled

      init_idempotency_key
    end

    def init_idempotency_key
      if @method == :post
        @headers['x-amz-pay-idempotency-key'] ||= SecureRandom.hex(14)
      end
    end

    ## bodyはpayloadで統一
    def call(current_time = nil)
      uri = api_uri
      url = uri.to_s
      request = METHOD_TYPES[@method].new(uri)

      if @payload && !@payload.kind_of?(String)
        request_payload_json = JSON.dump(@payload)
      else
        request_payload_json = @payload
      end
      request.body = request_payload_json

      request_parameters = {} ## currently, query string is not used
      request_headers = @headers

      time = current_time || Time.now.utc
      time_stamp = formatted_timestamp(time)

      pre_signed_headers = create_pre_signed_headers(url,
                                                     time_stamp,
                                                     request_headers)
      post_signed_headers = sign_request(@method,
                                         url,
                                         request_parameters,
                                         request_payload_json,
                                         pre_signed_headers)
      post_signed_headers.each { |key, value| request[key] = value }

      tries = 0
      begin
        http = Net::HTTP.new(uri.hostname,
                             uri.port,
                             @proxy_addr,
                             @proxy_port,
                             @proxy_user,
                             @proxy_pass)
        http.use_ssl = (uri.scheme == 'https')
        response = http.start do |h|
          h.request(request)
        end

        AmazonPay::ResponseV2.new(response)
      rescue StandardError => error
        tries += 1
        sleep(get_seconds_for_try_count(tries))
        retry if tries <= MAX_RETRIES
        raise error.message
      end
    end

    def get_seconds_for_try_count(try_count)
      seconds = { 1 => 1, 2 => 4, 3 => 10, 4 => 0 }
      seconds[try_count]
    end

    def api_uri
      api_endpoint = API_SERVICE_URL[@region.downcase]
      uri = URI("https://#{api_endpoint}/#{@sandbox}/#{@url_fragment}")
      uri
    end

    def generate_button_signature(payload)
      if payload.kind_of?(String)
        payload_json = payload
      else
        payload_json = JSON.dump(payload)
      end
      hashed_button_request = create_hashed_canonical_request(payload_json)
      rsa = OpenSSL::PKey::RSA.new(@private_pem)
      signature = Base64.strict_encode64(rsa.sign_pss(HASH_ALGORITHM,
                                                      hashed_button_request,
                                                      salt_length: 20,
                                                      mgf1_hash: HASH_ALGORITHM))
      signature
    end

    def create_pre_signed_headers(request_uri,
                                  time_stamp,
                                  other_headers)
      pre_signed_headers = {
        'accept' => 'application/json',
        'content-type' => 'application/json',
        'x-amz-pay-region' => @region,
        'x-amz-pay-date' => time_stamp,
        'x-amz-pay-host' => amz_pay_host(request_uri),
      }

      other_headers.each do |key, val|
        ## Javaでは追加
        ## PHPでは'x-amz-pay-idempotency-key'以外無視
        ## →とりあえず上書きに変更
        pre_signed_headers[key.downcase] = val
      end

      pre_signed_headers
    end

    def sign_request(http_request_method,
                     request_uri,
                     request_parameters,
                     request_payload,
                     pre_signed_headers)
      payload = check_for_payment_critical_data_api(request_uri,
                                                    http_request_method,
                                                    request_payload)

      signature = create_signature(http_request_method,
                                   request_uri,
                                   request_parameters,
                                   pre_signed_headers,
                                   payload)

      headers = canonical_headers(pre_signed_headers)

      signed_headers = "SignedHeaders=#{canonical_headers_names(headers)}, Signature=#{signature}"
      authorization = "#{AMAZON_SIGNATURE_ALGORITH} PublicKeyId=#{@public_key_id}, #{signed_headers}"

      header_array = {
        'accept' => string_from_array(headers['accept']),
        'content-type' => string_from_array(headers['content-type']),
        'x-amz-pay-host' => amz_pay_host(request_uri),
        'x-amz-pay-date' => headers['x-amz-pay-date'],
        'x-amz-pay-region' => @region,
        'x-amz-pay-idempotency-key' => headers['x-amz-pay-idempotency-key'],
        'authorization' => authorization,
        'user-agent' => user_agent_header,
      }
      # puts("\nAUTHORIZATION HEADER:\n" + header_array['authorization'])

      header_array.sort_by { |key, _value| key }.to_h
    end


    # Create the User Agent Header sent with the POST request */
    # Protected because of PSP module usaged */
    def user_agent_header
      "amazon-pay-sdk-ruby-v2/#{AmazonPay::VERSION} (Ruby/#{RUBY_VERSION})"
    end

    def create_signature(http_request_method,
                         request_uri,
                         request_parameters,
                         pre_signed_headers,
                         request_payload)
      canonical_request = create_canonical_request(http_request_method,
                                                   request_uri,
                                                   request_parameters,
                                                   pre_signed_headers,
                                                   request_payload)
      # puts("\nCANONICAL REQUEST:\n" + canonical_request)

      hashed_canonical_request = create_hashed_canonical_request(canonical_request)
      # puts("\nSTRING TO SIGN:\n" + hashed_canonical_request)

      rsa = OpenSSL::PKey::RSA.new(@private_pem)
      signature = Base64.strict_encode64(rsa.sign_pss(HASH_ALGORITHM,
                                                      hashed_canonical_request,
                                                      salt_length: 20,
                                                      mgf1_hash: HASH_ALGORITHM))
      signature
    end

    def create_canonical_request(http_request_method,
                                 request_uri,
                                 request_parameters,
                                 pre_signed_headers,
                                 request_payload)
        canonical_uri = canonical_uri_path(request_uri)
        canonical_query_string = create_canonical_query(request_parameters)
        canonical_header = header_string(pre_signed_headers)
        signed_headers = canonical_headers_names(pre_signed_headers)
        hashed_payload = hex_and_hash(request_payload)

        canonical_request = "#{http_request_method.to_s.upcase}\n" +
                            "#{canonical_uri}\n" +
                            "#{canonical_query_string}\n" +
                            "#{canonical_header}\n" +
                            "#{signed_headers}\n" +
                            "#{hashed_payload}"
        canonical_request
    end

    def create_hashed_canonical_request(canonical_request)
      "#{AMAZON_SIGNATURE_ALGORITH}\n#{hex_and_hash(canonical_request)}"
    end

    ##
    # HexEncode and hash data
    def hex_and_hash(data)
      Digest::SHA256.hexdigest(data)
    end

    ##
    # Takes the request uri and request payload, checks for
    # API names and modifies the payload if needed
    def check_for_payment_critical_data_api(request_uri,
                                            http_request_method,
                                            request_payload)
      payment_critical_data_apis = [
        '/live/account-management/v1/accounts',
        '/sandbox/account-management/v1/accounts'
      ]
      allowed_http_methods = %i(post put patch)

      # For APIs handling payment critical data, the payload shouldn't be
      # considered in the signature calculation
      payment_critical_data_apis.each do |api|
        if request_uri.include?(api) && allowed_http_methods.include?(http_request_method)
          return ''
        end
      end
      request_payload
    end

    ##
    # Formats date as ISO 8601 timestamp
    def formatted_timestamp(utc_time)
      utc_time.iso8601.gsub(/[-,:]/, '')
    end

    def canonical_headers(headers)
      canonical_array = headers.select{|k, v| v && !v.empty? }.map{|k, v| [k.to_s.downcase, v] }
      canonical_array.sort_by { |key, _value| key }.to_h
    end

    ##
    # Returns the host
    def amz_pay_host(url)
      return '/' unless url

      parsed_url = URI.parse(url)
      parsed_url.host || '/'
    end

    ##
    # Returns a string of the header names
    def canonical_headers_names(headers)
      canon = canonical_headers(headers)
      canon.map { |key, _value| key }.sort.join(';')
    end


    ##
    # helper function used to check if parameters is an array.
    # If it is array it returns all the values as a string
    # Otherwise it returns parameters
    def string_from_array(array_data)
      if array_data.kind_of?(Array)
        array_data.join(" ")
      else
        array_data
      end
    end

    def canonical_uri_path(unencoded_uri)
      if unencoded_uri == ''
        return '/'
      end

      path = URI.parse(unencoded_uri).path
      if path.to_s.empty?
        '/'
      else
        path
      end
    end

    ##
    # Returns a string of request parameters
    def create_canonical_query(request_parameters)
      sorted_request_parameters = sort_canonical_array(request_parameters)
      parameters_as_string(sorted_request_parameters)
    end

    def sort_canonical_array(canonical_array)
      sorted_canonical_array = {}
      canonical_array.sort_by{ |key, _v| key }.each do |key, val|
        if val.is_a?(Array)
          sub_arrays(val, key.to_s).each do |new_key, sub_val|
            sorted_canonical_array[new_key] = sub_val
          end
        elsif !val
          # ignore
        else
          sorted_canonical_array[key.to_s] = val
        end
      end
      sorted_canonical_array.sort_by { |key, _value| key }.to_h
    end

    ##
    # helper function used to break out arays in an array
    def sub_arrays(params, category)
      new_params = {}
      params.each_with_index do |value, idx|
        new_params["#{category}.#{idx + 1}"] = value
      end
      new_params
    end

    ##
    # Convert paremeters to Url encoded query string
    def parameters_as_string(params)
      params.map{|key, val| "#{key}=#{url_encode(val)}" }.join('&')
    end

    def url_encode(value)
      CGI.escape(value).gsub("+", "%20")
    end

    ##
    # Returns the Canonical Headers as a string
    def header_string(headers)
      sorted_headers = canonical_headers(headers)

      sorted_headers.map { |key, value|
        if value.is_a?(Array)
          "#{key}:#{value.join(' ').gsub(/  +/,' ')}"
        else
          "#{key}:#{value.gsub(/  +/,' ')}"
        end
      }.join("\n") + "\n"
    end

  end
end
