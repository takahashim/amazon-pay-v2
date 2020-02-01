require 'test_helper'
require 'json'
require 'amazon_pay/request_v2'
require 'webmock'


class AmazonPayRequestV2Test < Minitest::Test
  include WebMock::API

  def setup
    @pem_path = File.dirname(__FILE__) + "/fixtures/private.pem"
    @req = AmazonPay::RequestV2.new("v1/foo",
                                    public_key_id: "DUMMYKEYID",
                                    store_id: "amzn1.application-oa2-client.12345",
                                    method: :post,
                                    payload: nil,
                                    headers: {},
                                    private_pem_path: @pem_path
                                   )
  end

  def test_call
    post_url = ""
    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v1/checkoutSessions"
                ).with(body: post_url).to_return(status: 200)

    req = AmazonPay::RequestV2.new("v1/checkoutSessions",
                                   public_key_id: "DUMMYKEYID",
                                   store_id: "amzn1.application-oa2-client.12345",
                                   method: :post,
                                   payload: "",
                                   headers: {},
                                   sandbox: true,
                                   private_pem_path: @pem_path
                                  )
    cur_time = Time.gm(2019,9,23,23,19,8)
    result = req.call(cur_time)
    assert_equal("200", result.code)

  end

  def test_api_uri
    uri = @req.api_uri
    expected = "https://pay-api.amazon.jp/sandbox/v1/foo"
    assert_equal(expected, uri.to_s)
  end

  def test_create_pre_signed_headers
    params = @req.create_pre_signed_headers(
      "https://example.jp/some/endpoints",
      "20200215T032456Z",
      {}
    )
    expected = {"accept"=>"application/json",
                "content-type"=>"application/json",
                "x-amz-pay-region"=>"JP",
                "x-amz-pay-date"=>"20200215T032456Z",
                "x-amz-pay-host"=>"example.jp"}
    assert_equal(expected, params)
  end

  def test_user_agent_header
    params = @req.user_agent_header
    expected = "amazon-pay-sdk-ruby-v2/2.5.0 (Ruby/#{RUBY_VERSION})"
    assert_equal(expected, params)
  end

  def test_create_hashed_canonical_request
    canonical_request = <<-EOB.chomp
POST
/live/v1/checkoutSessions

accept:application/json
content-type:application/json
x-amz-pay-date:20190923T231908Z
x-amz-pay-host:pay-api.amazon.com
x-amz-pay-idempotency-key:cllHyiNvS8cJ8Zas
x-amz-pay-region:us

accept;content-type;x-amz-pay-date;x-amz-pay-host;x-amz-pay-idempotency-key;x-amz-pay-region
0b6c19dc5bc1883ebd68d3c77ee929922c6b4a59e0a506d96c45e0c024c3295b
EOB
    str = @req.create_hashed_canonical_request(canonical_request)

    expected = "AMZN-PAY-RSASSA-PSS\n" +
               "c5c55b2d523738b72c0b96f6d5e0d712d9496573490125b191eeb6840c052ffb"
    assert_equal(expected, str)
  end

  def test_sign_request
    headers = {"accept"=>"application/json",
               "content-type"=>"application/json",
               "x-amz-pay-idempotency-key"=>"cllHyiNvS8cJ8Zas",
               "x-amz-pay-region"=>"us",
               "x-amz-pay-date"=>"20190923T231908Z",
               "x-amz-pay-host"=>"pay-api.amazon.com"}
    body = JSON.dump({
      'webCheckoutDetail' => {
        'checkoutReviewReturnUrl' => "https://example.jp/merchant-review-page"
      },
      'storeId' => "amzn1.store.id"
    })

    req = @req.sign_request(
      :post,
      "https://pay-api.amazon.com/live/v1/checkoutSessions",
      {},
      body,
      headers,
    )

    expected = {"accept"=>"application/json",
                "authorization"=>"AMZN-PAY-RSASSA-PSS PublicKeyId=DUMMYKEYID, SignedHeaders=accept;content-type;x-amz-pay-date;x-amz-pay-host;x-amz-pay-idempotency-key;x-amz-pay-region,",
                "content-type"=>"application/json",
                "user-agent"=>"amazon-pay-sdk-ruby-v2/2.5.0 (Ruby/#{RUBY_VERSION})",
                "x-amz-pay-date"=>"20190923T231908Z",
                "x-amz-pay-host"=>"pay-api.amazon.com",
                "x-amz-pay-idempotency-key"=>"cllHyiNvS8cJ8Zas",
                "x-amz-pay-region"=>"JP"}
    req2 = req.dup
    req2["authorization"].gsub!(/ Signature=.*$/, "")
    assert_equal(expected, req2)
  end

  def test_create_signature
    headers = {"accept"=>"application/json",
               "content-type"=>"application/json",
               "x-amz-pay-idempotency-key"=>"cllHyiNvS8cJ8Zas",
               "x-amz-pay-region"=>"us",
               "x-amz-pay-date"=>"20190923T231908Z",
               "x-amz-pay-host"=>"pay-api.amazon.com"}
    body = JSON.dump({
      'webCheckoutDetail' => {
        'checkoutReviewReturnUrl' => "https://example.jp/merchant-review-page"
      },
      'storeId' => "amzn1.store.id"
    })

    req = @req.create_signature(
      :post,
      "https://pay-api.amazon.com/live/v1/checkoutSessions",
      {},
      headers,
      body
    )

    data = "AMZN-PAY-RSASSA-PSS\n" +
           "1efa4e9e223184a6d9cddb0b474be79cdd0bafcb298dc85d72c0a69a60588e63"

    rsa = OpenSSL::PKey::RSA.new(File.read(@pem_path))
    pub_key = rsa.public_key
    result = pub_key.verify_pss("SHA256",
                                Base64.strict_decode64(req),
                                data,
                                salt_length: :auto,
                                mgf1_hash: "SHA256")

    assert_equal(true, result)
  end

  def test_create_canonical_request
    headers = {"accept"=>"application/json",
               "content-type"=>"application/json",
               "x-amz-pay-idempotency-key"=>"cllHyiNvS8cJ8Zas",
               "x-amz-pay-region"=>"us",
               "x-amz-pay-date"=>"20190923T231908Z",
               "x-amz-pay-host"=>"pay-api.amazon.com"}
    body = JSON.dump({
      'webCheckoutDetail' => {
        'checkoutReviewReturnUrl' => "https://example.jp/merchant-review-page"
      },
      'storeId' => "amzn1.store.id"
    })

    req = @req.create_canonical_request(
      :post,
      "https://pay-api.amazon.com/live/v1/checkoutSessions",
      {},
      headers,
      body
    )
    expected = <<-EOB.chomp
POST
/live/v1/checkoutSessions

accept:application/json
content-type:application/json
x-amz-pay-date:20190923T231908Z
x-amz-pay-host:pay-api.amazon.com
x-amz-pay-idempotency-key:cllHyiNvS8cJ8Zas
x-amz-pay-region:us

accept;content-type;x-amz-pay-date;x-amz-pay-host;x-amz-pay-idempotency-key;x-amz-pay-region
c24cf3344641ba92f4d16246aab4d6f28325b7466d7adee5bc3bd2f23fdc4949
EOB
    assert_equal(expected, req)
  end

  def test_header_string
    params = @req.header_string({"foo"=>"a b"})
    expected = "foo:a b\n"
    assert_equal(expected, params)
  end

  def test_header_string2
    params = @req.header_string({"foo"=>"a b", "bar" => "buz"})
    expected = "bar:buz\nfoo:a b\n"
    assert_equal(expected, params)
  end

  def test_header_string_spaces
    params = @req.header_string({"foo"=>"a b  c", "bar" => "bu    z"})
    expected = "bar:bu z\nfoo:a b c\n"
    assert_equal(expected, params)
  end

  def test_parameters_as_string
    params = @req.parameters_as_string({"foo"=>"a b", "bar" => "buz"})
    expected = "foo=a%20b&bar=buz"
    assert_equal(expected, params)
  end

  def test_sub_arrays
    params = @req.sub_arrays(["foo", "bar", "buz"], "cat")
    expected = {"cat.1"=>"foo", "cat.2"=>"bar", "cat.3"=>"buz"}
    assert_equal(expected, params)
  end

  def test_sort_canonical_array
    params = @req.sort_canonical_array({"foo"=>["a", "b"], "bar" => "buz"})
    expected = {"bar"=>"buz", "foo.1"=>"a", "foo.2"=>"b"}
    assert_equal(expected, params)
  end

  def test_create_canonical_query
    params = @req.create_canonical_query({"foo"=>["a", "b"], "bar" => "buz"})
    expected = "bar=buz&foo.1=a&foo.2=b"
    assert_equal(expected, params)
  end

  def test_create_canonical_query_empty
    params = @req.create_canonical_query({})
    expected = ""
    assert_equal(expected, params)
  end

  def test_sub_arrays_empty
    params = @req.sub_arrays([], "cat")
    expected = {}
    assert_equal(expected, params)
  end

  def test_canonical_uri_empty
    str = @req.canonical_uri_path("")
    assert_equal("/", str)
  end

  def test_canonical_uri
    str = @req.canonical_uri_path("https://example.jp/foo/bar?buz")
    assert_equal("/foo/bar", str)
  end

  def test_string_from_array_empty
    data = []
    str = @req.string_from_array(data)
    expected = ""
    assert_equal(expected, str)
  end

  def test_string_from_array_array1
    data = ["foo"]
    str = @req.string_from_array(data)
    expected = "foo"
    assert_equal(expected, str)
  end

  def test_string_from_array_array
    data = ["foo", "_bar", "Buz"]
    str = @req.string_from_array(data)
    expected = "foo _bar Buz"
    assert_equal(expected, str)
  end

  def test_string_from_array_str
    data = "foo-bar buz"
    str = @req.string_from_array(data)
    expected = "foo-bar buz"
    assert_equal(expected, str)
  end

  def test_canonical_headers_names
    headers = {"X-Foo-Bar" => "buz2",
               "x-foo" => "buz"}
    names = @req.canonical_headers_names(headers)
    expected = "x-foo;x-foo-bar"
    assert_equal(expected, names)
  end

  def test_amz_pay_host
    url = @req.amz_pay_host("https://example.jp/amz")
    expected = "example.jp"
    assert_equal(expected, url)
  end

  def test_amz_pay_host_nil
    url = @req.amz_pay_host(nil)
    expected = "/"
    assert_equal(expected, url)
  end

  def test_url_encode_normal
    url = @req.url_encode("https://example.jp")
    expected = "https%3A%2F%2Fexample.jp"
    assert_equal(expected, url)
  end

  def test_url_encode_tilde
    url = @req.url_encode("https://example.jp/~foo/bar#buz")
    expected = "https%3A%2F%2Fexample.jp%2F~foo%2Fbar%23buz"
    assert_equal(expected, url)
  end

  def test_url_encode_space
    url = @req.url_encode("https://example.jp/ foo")
    expected = "https%3A%2F%2Fexample.jp%2F%20foo"
    assert_equal(expected, url)
  end

  def test_hex_and_hash
    data = "x-foo"
    digest = @req.hex_and_hash(data)
    expected = "2f937f08826a02d33e51a99e4e82c88ba1a3232140ebe25c4f193643bbac8657"
    assert_equal(expected, digest)
  end


  def test_formatted_timestamp
    t = @req.formatted_timestamp(Time.gm(2020,02,15,3,24,56))
    expected = "20200215T032456Z"
    assert_equal(expected, t)
  end

  def test_canonical_headers_case
    headers = {"X-Foo-Bar" => "buz"}
    canon = @req.canonical_headers(headers)
    expected = {"x-foo-bar" => "buz"}
    assert_equal(expected, canon)
  end

  def test_canonical_headers_symbol_key
    headers = {XFooBar: "buz"}
    canon = @req.canonical_headers(headers)
    expected = {"xfoobar" => "buz"}
    assert_equal(expected, canon)
  end

  def test_canonical_headers_duplicated_key
    headers = {"X-Foo-Bar" => "buz",
               "x-foo-bar" => "buz2"}
    canon = @req.canonical_headers(headers)
    expected = {"x-foo-bar" => "buz2"}
    assert_equal(expected, canon)
  end

  def test_canonical_headers_sort
    headers = {"x-foo2" => "buz2",
               "x-foo-bar" => "buz_bar",
               "x-foo" => "buz",
              }
    canon = @req.canonical_headers(headers)
    expected = {"x-foo"=>"buz",
                "x-foo-bar"=>"buz_bar",
                "x-foo2"=>"buz2"}

    assert_equal(expected, canon)
  end
end

