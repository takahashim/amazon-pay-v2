module AmazonPay
  # This class provides helpers to parse the response
  class ResponseV2
    def initialize(response)
      @response = response
    end

    def body
      @response.body
    end

    def parsed_body
      JSON.parse(body)
    end

    def code
      @response.code
    end

    def success
      @response.code == '200' || @response.code == '201'
    end

    alias_method :success?, :success
  end
end
