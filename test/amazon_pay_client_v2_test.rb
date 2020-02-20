require 'test_helper'
require 'json'
require 'amazon_pay/client_v2'
require 'webmock'


class AmazonPayClientV2Test < Minitest::Test
  include WebMock::API

  def setup
    @pem_path = File.dirname(__FILE__) + "/fixtures/private.pem"
    @cli = AmazonPay::ClientV2.new(public_key_id: "DUMMYKEYID",
                                   private_pem_path: @pem_path,
                                   sandbox: true,
                                   region: 'JP',
                                  )
  end

  def test_create_checkout_session
    payload = ""
    headers = {}

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v1/checkoutSessions"
                ).with(body: payload).to_return(status: 200)

    result = @cli.create_checkout_session(payload,
                                          headers: headers)
    assert_equal("200", result.code)
  end

end

