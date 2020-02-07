require 'amazon_pay/request_v2'

module AmazonPay
  class ClientV2
    attr_reader(
      :sandbox,
      :currency_code,
      :region,
      :private_pem_path,
      :log_enabled,
      :log_file_name,
      :log_level
    )

    attr_accessor(
      :proxy_addr,
      :proxy_port,
      :proxy_user,
      :proxy_pass
    )

    def initialize(
          public_key_id:,
          store_id:,
          sandbox: false,
          currency_code: :usd,
          region: :na,
          private_pem_path: nil,
          proxy_addr: :ENV,
          proxy_port: nil,
          proxy_user: nil,
          proxy_pass: nil,
          log_enabled: false,
          log_file_name: nil,
          log_level: :DEBUG
        )

      @public_key_id = public_key_id
      @store_id = store_id
      @currency_code = currency_code.to_s.upcase
      @sandbox = sandbox
      @region = region
      @private_pem_path = private_pem_path

      @proxy_addr = proxy_addr
      @proxy_port = proxy_port
      @proxy_user = proxy_user
      @proxy_pass = proxy_pass

      @log_enabled = log_enabled
      @log_level = log_level
      @log_file_name = log_file_name
    end

    def api_call(url_fragment, method:, payload:, headers:)
      AmazonPay::RequestV2.new(
        url_fragment,
        method: method,
        payload: payload,
        headers: headers,
        private_pem_path: @private_pem_path,
        public_key_id: @public_key_id,
        store_id: @store_id,

        sandbox: @sandbox,
        region: @region,
        proxy_addr: @proxy_addr,
        proxy_port: @proxy_port,
        proxy_user: @proxy_user,
        proxy_pass: @proxy_pass,

        log_enabled: @log_enabled,
        log_level: @log_level,
        log_file_name: @log_file_name
      ).call
    end

    ## API V2
    def create_checkout_session(payload, headers: nil)
      api_call('v1/checkoutSessions',
               method: :post, payload: payload, headers: headers)
    end

    def get_checkout_session(checkout_session_id, headers: nil)
      api_call("v1/checkoutSessions/#{checkout_session_id}",
               method: :get, headers: headers, payload: nil)
    end


    def update_checkout_session(checkout_session_id, payload, headers: nil)
      api_call("v1/checkoutSessions/#{checkout_session_id}",
               method: :patch, payload: payload, headers: headers)
    end


    def get_charge_permission(charge_permission_id, headers: nil)
      api_call("v1/chargePermissions/#{charge_permission_id}",
               mehotd: :get, headers: headers)
    end


    def update_charge_permission(charge_permission_id, payload, headers: nil)
      api_call("v1/chargePermissions/#{charge_permission_id}",
               method: :patch, payload: payload, headers: headers)
    end


    def close_charge_permission(charge_permission_id, payload, headers: nil)
      api_call("v1/chargePermissions/#{charge_permission_id}/close",
               method: :delete, payload: payload, headers: headers)
    end


    def create_charge(payload, headers: nil)
      api_call('v1/charges',
               method: :post, payload: payload, headers: headers)
    end


    def get_charge(charge_id, headers: nil)
      api_call("v1/charges/#{charge_id}",
               method: :get, headers: headers, payload: nil)
    end


    def capture_charge(charge_id, payload, headers: nil)
      api_call("v1/charges/#{charge_id}/capture",
               method: :post, payload: payload, headers: headers)
    end


    def cancel_charge(charge_id, payload, headers: nil)
      api_call('DELETE', "v1/charges/#{charge_id}/cancel",
               method: :delete, payload: payload, headers: headers)
    end


    def create_refund(payload, headers: nil)
      api_call('v1/refunds',
               method: :post, payload: payload, headers: headers)
    end


    def get_refund(refund_id, headers: nil)
      api_call("v1/refunds/#{refund_id}",
               method: :get, headers: headers)
    end
  end
end
