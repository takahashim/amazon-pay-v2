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
      @response.code.eql? '200'
    end
  end
end
