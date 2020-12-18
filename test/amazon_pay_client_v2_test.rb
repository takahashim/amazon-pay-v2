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

  def test_create_checkout_session_null
    payload = ""
    headers = {}
    body = %Q({"checkoutSessionId":"be4cbb1e-c411-4719-b44c-1af8b1dc0ee1","webCheckoutDetail":{"checkoutReviewReturnUrl":"https://localhost:3000/user_session/amazon_login","checkoutResultReturnUrl":null,"amazonPayRedirectUrl":null},"productType":null,"paymentDetail":{"paymentIntent":null,"canHandlePendingAuthorization":false,"chargeAmount":null,"softDescriptor":null,"presentmentCurrency":null},"merchantMetadata":{"merchantReferenceId":null,"merchantStoreName":null,"noteToBuyer":null,"customInformation":null},"supplementaryData":null,"buyer":null,"paymentPreferences":[null],"statusDetail":{"state":"Open","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200220T154900Z"},"shippingAddress":null,"platformId":null,"chargePermissionId":null,"chargeId":null,"constraints":[{"constraintId":"BuyerNotAssociated","description":"There is no buyer associated with the Checkout Session. Return the checkout session id to the Amazon Pay Button to allow buyer to login."},{"constraintId":"ChargeAmountNotSet","description":"chargeAmount is not set."},{"constraintId":"CheckoutResultReturnUrlNotSet","description":"checkoutResultReturnUrl is not set."},{"constraintId":"PaymentIntentNotSet","description":"paymentIntent is not set."}],"creationTimestamp":"20200220T154900Z","expirationTimestamp":"20200221T154900Z","storeId":"amzn1.application-oa2-client.dummy123","providerMetadata":{"providerReferenceId":null},"releaseEnvironment":"Sandbox","deliverySpecifications":null})

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v2/checkoutSessions"
                ).with(body: payload).to_return(status: 200, body: body)
    result = @cli.create_checkout_session(payload,
                                          headers: headers)
    assert_equal("200", result.code)
    assert_equal(true, result.success?)
    res_body = result.parsed_body
    assert_equal("be4cbb1e-c411-4719-b44c-1af8b1dc0ee1",
                 res_body["checkoutSessionId"])
    assert_equal("be4cbb1e-c411-4719-b44c-1af8b1dc0ee1",
                 res_body["checkoutSessionId"])
  end

  def test_create_checkout_session
    payload2 =
      {
        "webCheckoutDetail" => {
          "checkoutReviewReturnUrl" => "https://example.jp/review_url",
          'checkoutResultReturnUrl' => "https://example.jp/result_url"
        },
        "storeId" => "amzn1.application-oa2-client.dummy123",
        'paymentDetail' => {
          'paymentIntent' => 'Authorize',
          'canHandlePendingAuthorization' => false,
          'chargeAmount' => {
            'amount' => 500,
            'currencyCode' => 'JPY'
          }
        },
        'merchantMetadata' => {
          'merchantReferenceId' => "xxx_authorization_reference_id",
          'merchantStoreName' => 'MyStore',
          'noteToBuyer' => "item_name",
        }
      }

    body2 = %Q({"checkoutSessionId":"6f916c70-c611-4adb-af5c-8204e68cd8e0","webCheckoutDetail":{"checkoutReviewReturnUrl":"https://example.jp/review_url","checkoutResultReturnUrl":"https://example.jp/result_url","amazonPayRedirectUrl":null},"productType":null,"paymentDetail":{"paymentIntent":"Authorize","canHandlePendingAuthorization":false,"chargeAmount":{"amount":"500","currencyCode":"JPY"},"softDescriptor":null,"presentmentCurrency":null},"merchantMetadata":{"merchantReferenceId":"xxx_authorization_reference_id","merchantStoreName":"MyStore","noteToBuyer":"item_name","customInformation":null},"supplementaryData":null,"buyer":null,"paymentPreferences":[null],"statusDetail":{"state":"Open","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T041614Z"},"shippingAddress":null,"platformId":null,"chargePermissionId":null,"chargeId":null,"constraints":[{"constraintId":"BuyerNotAssociated","description":"There is no buyer associated with the Checkout Session. Return the checkout session id to the Amazon Pay Button to allow buyer to login."}],"creationTimestamp":"20200222T041614Z","expirationTimestamp":"20200223T041614Z","storeId":"amzn1.application-oa2-client.dummy123","providerMetadata":{"providerReferenceId":null},"releaseEnvironment":"Sandbox","deliverySpecifications":null})

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v2/checkoutSessions"
                ).with(body: payload2).to_return(status: 200, body: body2)

    result = @cli.create_checkout_session(payload2)

    assert_equal("200", result.code)
    assert_equal(true, result.success?)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal("6f916c70-c611-4adb-af5c-8204e68cd8e0",
                 res_body["checkoutSessionId"])
    assert_equal("JPY",
                 res_body["paymentDetail"]["chargeAmount"]["currencyCode"])
    assert_equal("500",
                 res_body["paymentDetail"]["chargeAmount"]["amount"])
    assert_equal("Open",
                 res_body["statusDetail"]["state"])
    assert_equal("https://example.jp/review_url",
                 res_body["webCheckoutDetail"]["checkoutReviewReturnUrl"])
  end

  def test_get_checkout_session
    body = %Q({"checkoutSessionId":"6f916c70-c611-4adb-af5c-8204e68cd8e0","webCheckoutDetail":{"checkoutReviewReturnUrl":"https://example.jp/review_url","checkoutResultReturnUrl":"https://example.jp/result_url","amazonPayRedirectUrl":"https://payments.amazon.co.jp/checkout/processing?amazonCheckoutSessionId=6f916c70-c611-4adb-af5c-8204e68cd8e0"},"productType":"PayAndShip","paymentDetail":{"paymentIntent":"Authorize","canHandlePendingAuthorization":false,"chargeAmount":{"amount":"500","currencyCode":"JPY"},"softDescriptor":null,"presentmentCurrency":null},"merchantMetadata":{"merchantReferenceId":"xxx_authorization_reference_id","merchantStoreName":"MyStore","noteToBuyer":"item_name","customInformation":null},"supplementaryData":null,"buyer":{"name":"buyer_test","email":"buyer-test@example.com","buyerId":"amzn1.account.BUYERDUMMY"},"paymentPreferences":[{"billingAddress":null,"paymentDescriptor":"Amazon Pay"}],"statusDetail":{"state":"Open","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T080826Z"},"shippingAddress":{"name":"JP test1","addressLine1":"4-1-1 Kamikodanaka; Nakahara-ku","addressLine2":null,"addressLine3":null,"city":"Kawasaki-shi","county":null,"district":null,"stateOrRegion":"Kanagawa","postalCode":"211-8588","countryCode":"JP","phoneNumber":"09057311712"},"platformId":null,"chargePermissionId":null,"chargeId":null,"constraints":[],"creationTimestamp":"20200222T041614Z","expirationTimestamp":"20200223T041614Z","storeId":"amzn1.application-oa2-client.dummy123","providerMetadata":{"providerReferenceId":null},"releaseEnvironment":"Sandbox","deliverySpecifications":null})

    checkout_session_id = "6f916c70-c611-4adb-af5c-8204e68cd8e0"

    stub_request(:get,
                 "https://pay-api.amazon.jp/sandbox/v2/checkoutSessions/#{checkout_session_id}"
                ).to_return(status: 200, body: body)
    result = @cli.get_checkout_session(checkout_session_id)

    assert_equal("200", result.code)
    assert_equal(true, result.success?)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal("6f916c70-c611-4adb-af5c-8204e68cd8e0",
                 res_body["checkoutSessionId"])
    assert_equal("JPY",
                 res_body["paymentDetail"]["chargeAmount"]["currencyCode"])
    assert_equal("500",
                 res_body["paymentDetail"]["chargeAmount"]["amount"])
    assert_equal("Open",
                 res_body["statusDetail"]["state"])
    assert_equal("buyer_test",
                 res_body["buyer"]["name"])
    assert_equal("buyer-test@example.com",
                 res_body["buyer"]["email"])
    assert_equal("JP test1",
                 res_body["shippingAddress"]["name"])
    assert_equal("211-8588",
                 res_body["shippingAddress"]["postalCode"])
  end


  def test_update_checkout_session
    payload = {
      'webCheckoutDetail' => {'checkoutResultReturnUrl' => 'http://localhost:8001/php/result_return.php'},
      'paymentDetail' => {
        'chargeAmount' => {
          'amount' => '300',
          'currencyCode' => 'JPY'
        },
      },
      'merchantMetadata' => {
        'merchantReferenceId' => '2020-00000002',
        'merchantStoreName' => 'MyStore2',
        'noteToBuyer' => 'Thank you for your order!',
        'customInformation' => 'Custom information'
      }
    }

    body = %Q({"checkoutSessionId":"6f916c70-c611-4adb-af5c-8204e68cd8e0","webCheckoutDetail":{"checkoutReviewReturnUrl":"https://example.jp/review_url","checkoutResultReturnUrl":"http://localhost:8001/php/result_return.php","amazonPayRedirectUrl":"https://payments.amazon.co.jp/checkout/processing?amazonCheckoutSessionId=6f916c70-c611-4adb-af5c-8204e68cd8e0"},"productType":"PayAndShip","paymentDetail":{"paymentIntent":"Authorize","canHandlePendingAuthorization":false,"chargeAmount":{"amount":"300","currencyCode":"JPY"},"softDescriptor":null,"presentmentCurrency":"JPY"},"merchantMetadata":{"merchantReferenceId":"2020-00000002","merchantStoreName":"MyStore2","noteToBuyer":"Thank you for your order!","customInformation":"Custom information"},"supplementaryData":null,"buyer":{"name":"buyer_test","email":"buyer-test@example.com","buyerId":"amzn1.account.BUYERDUMMY"},"paymentPreferences":[{"billingAddress":null,"paymentDescriptor":"Amazon Pay"}],"statusDetail":{"state":"Open","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T092520Z"},"shippingAddress":{"name":"JP test1","addressLine1":"4-1-1 Kamikodanaka; Nakahara-ku","addressLine2":null,"addressLine3":null,"city":"Kawasaki-shi","county":null,"district":null,"stateOrRegion":"Kanagawa","postalCode":"211-8588","countryCode":"JP","phoneNumber":"09057311712"},"platformId":null,"chargePermissionId":null,"chargeId":null,"constraints":[],"creationTimestamp":"20200222T041614Z","expirationTimestamp":"20200223T041614Z","storeId":"amzn1.application-oa2-client.dummy123","providerMetadata":{"providerReferenceId":null},"releaseEnvironment":"Sandbox","deliverySpecifications":null})

    checkout_session_id = "6f916c70-c611-4adb-af5c-8204e68cd8e0"

    stub_request(:patch,
                 "https://pay-api.amazon.jp/sandbox/v2/checkoutSessions/#{checkout_session_id}"
                ).to_return(status: 200, body: body)
    result = @cli.update_checkout_session(checkout_session_id, payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success?)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal("6f916c70-c611-4adb-af5c-8204e68cd8e0",
                 res_body["checkoutSessionId"])
    assert_equal("JPY",
                 res_body["paymentDetail"]["chargeAmount"]["currencyCode"])
    assert_equal("300",
                 res_body["paymentDetail"]["chargeAmount"]["amount"])
    assert_equal("Open",
                 res_body["statusDetail"]["state"])
    assert_equal("buyer_test",
                 res_body["buyer"]["name"])
    assert_equal("buyer-test@example.com",
                 res_body["buyer"]["email"])
    assert_equal("JP test1",
                 res_body["shippingAddress"]["name"])
    assert_equal("211-8588",
                 res_body["shippingAddress"]["postalCode"])
    assert_equal("https://payments.amazon.co.jp/checkout/processing?amazonCheckoutSessionId=6f916c70-c611-4adb-af5c-8204e68cd8e0",
                 res_body["webCheckoutDetail"]["amazonPayRedirectUrl"])
  end

  def test_complete_checkout_session
    payload = {
      'chargeAmount' => {
        'amount' => '300',
        'currencyCode' => 'JPY'
      }
    }

    body = %Q({"checkoutSessionId":"6f916c70-c611-4adb-af5c-8204e68cd8e0","webCheckoutDetail":null,"productType":"PayAndShip","paymentDetail":null,"merchantMetadata":null,"supplementaryData":null,"buyer":null,"paymentPreferences":[null],"statusDetail":{"state":"Complete","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T092520Z"},"shippingAddress":null,"platformId":null,"chargePermissionId":null,"chargeId":null,"constraints":[],"creationTimestamp":"20200222T041614Z","expirationTimestamp":"20200223T041614Z","storeId":"amzn1.application-oa2-client.dummy123","providerMetadata":{"providerReferenceId":null},"releaseEnvironment":"Sandbox","deliverySpecifications":null})

    checkout_session_id = "6f916c70-c611-4adb-af5c-8204e68cd8e0"

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v2/checkoutSessions/#{checkout_session_id}/complete"
                ).to_return(status: 200, body: body)
    result = @cli.complete_checkout_session(checkout_session_id, payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success?)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal("6f916c70-c611-4adb-af5c-8204e68cd8e0",
                 res_body["checkoutSessionId"])
    assert_nil(res_body["paymentDetail"])
    assert_equal("Complete",
                 res_body["statusDetail"]["state"])
  end


  def test_get_charge_permission
    body = %Q({"chargePermissionId":"S03-4260904-6894064","chargePermissionReferenceId":null,"platformId":null,"buyer":{"name":"buyer_test","email":"buyer-test@example.com","buyerId":"amzn1.account.BUYERDUMMY"},"shippingAddress":{"name":"JP test1","addressLine1":"4-1-1 Kamikodanaka; Nakahara-ku","addressLine2":null,"addressLine3":null,"city":"Kawasaki-shi","county":null,"district":null,"stateOrRegion":"Kanagawa","postalCode":"211-8588","countryCode":"JP","phoneNumber":"09057311712"},"paymentPreferences":[{"billingAddress":null,"paymentDescriptor":null}],"statusDetail":{"state":"NonChargeable","reasons":[{"reasonCode":"ChargeInProgress","reasonDescription":"A charge is already in progress. You cannot initiate a new charge unless previous charge is canceled."}],"lastUpdatedTimestamp":"20200222T100318Z"},"creationTimestamp":"20200222T100318Z","expirationTimestamp":"20200820T100318Z","merchantMetadata":{"merchantReferenceId":"2020-00000002","merchantStoreName":"MyStore2","noteToBuyer":"Thank you for your order!","customInformation":"Custom information"},"releaseEnvironment":"Sandbox","chargeAmountLimit":{"amount":"300","currencyCode":"JPY"},"presentmentCurrency":"JPY"})

    charge_permission_id = "S03-4260904-6894064"

    stub_request(:get,
                 "https://pay-api.amazon.jp/sandbox/v2/chargePermissions/#{charge_permission_id}"
                ).to_return(status: 200, body: body)
    result = @cli.get_charge_permission(charge_permission_id)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_permission_id,
                 res_body["chargePermissionId"])
    assert_equal("JPY",
                 res_body["chargeAmountLimit"]["currencyCode"])
    assert_equal("300",
                 res_body["chargeAmountLimit"]["amount"])
    assert_equal("NonChargeable",
                 res_body["statusDetail"]["state"])
    assert_equal("buyer_test",
                 res_body["buyer"]["name"])
    assert_equal("buyer-test@example.com",
                 res_body["buyer"]["email"])
    assert_equal("JP test1",
                 res_body["shippingAddress"]["name"])
    assert_equal("211-8588",
                 res_body["shippingAddress"]["postalCode"])
  end

  def test_update_charge_permission
    payload = {
      "merchantMetadata" => {
        "noteToBuyer" => "more Note to buyer",
        "customInformation" => "more custom information"
      }
    }

    body = %Q({"chargePermissionId":"S03-4260904-6894064","chargePermissionReferenceId":null,"platformId":null,"buyer":{"name":"buyer_test","email":"buyer-test@example.com","buyerId":"amzn1.account.BUYERDUMMY"},"shippingAddress":{"name":"JP test1","addressLine1":"4-1-1 Kamikodanaka; Nakahara-ku","addressLine2":null,"addressLine3":null,"city":"Kawasaki-shi","county":null,"district":null,"stateOrRegion":"Kanagawa","postalCode":"211-8588","countryCode":"JP","phoneNumber":"09057311712"},"paymentPreferences":[{"billingAddress":null,"paymentDescriptor":null}],"statusDetail":{"state":"Chargeable","reasons":null,"lastUpdatedTimestamp":"20200222T110013Z"},"creationTimestamp":"20200222T100318Z","expirationTimestamp":"20200820T100318Z","merchantMetadata":{"merchantReferenceId":"2020-00000002","merchantStoreName":"MyStore2","noteToBuyer":"more Note to buyer","customInformation":"more custom information"},"releaseEnvironment":"Sandbox","chargeAmountLimit":{"amount":"300","currencyCode":"JPY"},"presentmentCurrency":"JPY"})

    charge_permission_id = "S03-4260904-6894064"

    stub_request(:patch,
                 "https://pay-api.amazon.jp/sandbox/v2/chargePermissions/#{charge_permission_id}"
                ).with(body: payload).to_return(status: 200, body: body)
    result = @cli.update_charge_permission(charge_permission_id, payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_permission_id,
                 res_body["chargePermissionId"])
    assert_equal("JPY",
                 res_body["chargeAmountLimit"]["currencyCode"])
    assert_equal("300",
                 res_body["chargeAmountLimit"]["amount"])
    assert_equal("Chargeable",
                 res_body["statusDetail"]["state"])
    assert_equal("buyer_test",
                 res_body["buyer"]["name"])
    assert_equal("buyer-test@example.com",
                 res_body["buyer"]["email"])
    assert_equal("JP test1",
                 res_body["shippingAddress"]["name"])
    assert_equal("211-8588",
                 res_body["shippingAddress"]["postalCode"])
  end

  def test_close_charge_permission
    payload = {
      "closureReason" => "No more charges required",
      "cancelPendingCharges" => false
    }

    body = %Q({"chargePermissionId":"S03-4260904-6894064","chargePermissionReferenceId":null,"platformId":null,"buyer":{"name":"buyer_test","email":"buyer-test@example.com","buyerId":"amzn1.account.BUYERDUMMY"},"shippingAddress":{"name":"JP test1","addressLine1":"4-1-1 Kamikodanaka; Nakahara-ku","addressLine2":null,"addressLine3":null,"city":"Kawasaki-shi","county":null,"district":null,"stateOrRegion":"Kanagawa","postalCode":"211-8588","countryCode":"JP","phoneNumber":"09057311712"},"paymentPreferences":[{"billingAddress":null,"paymentDescriptor":null}],"statusDetail":{"state":"Closed","reasons":[{"reasonCode":"MerchantClosed","reasonDescription":"No more charges required"}],"lastUpdatedTimestamp":"20200222T111637Z"},"creationTimestamp":"20200222T100318Z","expirationTimestamp":"20200820T100318Z","merchantMetadata":{"merchantReferenceId":"2020-00000002","merchantStoreName":"MyStore2","noteToBuyer":"more Note to buyer","customInformation":"more custom information"},"releaseEnvironment":"Sandbox","chargeAmountLimit":{"amount":"300","currencyCode":"JPY"},"presentmentCurrency":"JPY"})

    charge_permission_id = "S03-4260904-6894064"

    stub_request(:delete,
                 "https://pay-api.amazon.jp/sandbox/v2/chargePermissions/#{charge_permission_id}/close"
                ).with(body: payload).to_return(status: 200, body: body)
    result = @cli.close_charge_permission(charge_permission_id, payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_permission_id,
                 res_body["chargePermissionId"])
    assert_equal("JPY",
                 res_body["chargeAmountLimit"]["currencyCode"])
    assert_equal("300",
                 res_body["chargeAmountLimit"]["amount"])
    assert_equal("Closed",
                 res_body["statusDetail"]["state"])
    assert_equal("MerchantClosed",
                 res_body["statusDetail"]["reasons"][0]["reasonCode"])
    assert_equal("No more charges required",
                 res_body["statusDetail"]["reasons"][0]["reasonDescription"])
  end

  def test_get_charge
    body = %Q({"chargeId":"S03-4260904-6894064-C010879","chargeAmount":{"amount":"300","currencyCode":"JPY"},"chargePermissionId":"S03-4260904-6894064","captureAmount":null,"refundedAmount":null,"softDescriptor":null,"providerMetadata":{"providerReferenceId":null},"convertedAmount":null,"conversionRate":null,"statusDetail":{"state":"Authorized","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T100319Z"},"creationTimestamp":"20200222T100319Z","expirationTimestamp":"20200323T100319Z","releaseEnvironment":"Sandbox"})

    charge_id = "S03-4260904-6894064-C010879"

    stub_request(:get,
                 "https://pay-api.amazon.jp/sandbox/v2/charges/#{charge_id}"
                ).to_return(status: 200, body: body)
    result = @cli.get_charge(charge_id)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_id,
                 res_body["chargeId"])
    assert_equal("JPY",
                 res_body["chargeAmount"]["currencyCode"])
    assert_equal("300",
                 res_body["chargeAmount"]["amount"])
    assert_equal("Authorized",
                 res_body["statusDetail"]["state"])
  end

  def test_capture_charge
    payload = {
      "captureAmount" => {
        "amount" => "300",
        "currencyCode" => "JPY"
      },
      "softDescriptor" => "SOFT-DESC"
    }

    body = %Q({"chargeId":"S03-4260904-6894064-C010879","chargeAmount":{"amount":"300","currencyCode":"JPY"},"chargePermissionId":"S03-4260904-6894064","captureAmount":{"amount":"300","currencyCode":"JPY"},"refundedAmount":{"amount":"0","currencyCode":"JPY"},"softDescriptor":"AMZ*SOFT-DESC","providerMetadata":{"providerReferenceId":null},"convertedAmount":null,"conversionRate":null,"statusDetail":{"state":"Captured","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T122633Z"},"creationTimestamp":"20200222T100319Z","expirationTimestamp":"20200323T100319Z","releaseEnvironment":"Sandbox"})

    charge_id = "S03-4260904-6894064-C010879"

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v2/charges/#{charge_id}/capture"
                ).to_return(status: 200, body: body)
    result = @cli.capture_charge(charge_id, payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_id,
                 res_body["chargeId"])
    assert_equal("JPY",
                 res_body["chargeAmount"]["currencyCode"])
    assert_equal("300",
                 res_body["chargeAmount"]["amount"])
    assert_equal("Captured",
                 res_body["statusDetail"]["state"])
    assert_equal("AMZ*SOFT-DESC",
                 res_body["softDescriptor"])
  end

  def test_create_refund
    charge_id = "S03-4260904-6894064-C010879"
    payload = {
      "chargeId" => charge_id,
      "refundAmount" => {
        "amount" => "100",
        "currencyCode" => "JPY"
      }
    }

    body = %Q({"refundId":"S03-4260904-6894064-R064628","chargeId":"S03-4260904-6894064-C010879","creationTimestamp":1582374729128,"refundAmount":{"amount":"100.00","currencyCode":"JPY"},"statusDetail":{"state":"RefundInitiated","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T123209Z"},"softDescriptor":"AMZ*MyStore","releaseEnvironment":"Sandbox"})

    charge_id = "S03-4260904-6894064-C010879"

    stub_request(:post,
                 "https://pay-api.amazon.jp/sandbox/v2/refunds"
                ).with(body: payload).to_return(status: 200, body: body)
    result = @cli.create_refund(payload)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(charge_id,
                 res_body["chargeId"])
    assert_equal("JPY",
                 res_body["refundAmount"]["currencyCode"])
    assert_equal("100.00",
                 res_body["refundAmount"]["amount"])
    assert_equal("RefundInitiated",
                 res_body["statusDetail"]["state"])
  end

  def test_get_refund
    refund_id = "S03-4260904-6894064-R064628"

    body = %Q({"refundId":"S03-4260904-6894064-R064628","chargeId":"S03-4260904-6894064-C010879","creationTimestamp":1582374729128,"refundAmount":{"amount":"100.00","currencyCode":"JPY"},"statusDetail":{"state":"Refunded","reasonCode":null,"reasonDescription":null,"lastUpdatedTimestamp":"20200222T123239Z"},"softDescriptor":"AMZ*MyStore","releaseEnvironment":"Sandbox"})

    stub_request(:get,
                 "https://pay-api.amazon.jp/sandbox/v2/refunds/#{refund_id}"
                ).to_return(status: 200, body: body)
    result = @cli.get_refund(refund_id)

    assert_equal("200", result.code)
    assert_equal(true, result.success)

    res_body = result.parsed_body
    assert_equal(refund_id,
                 res_body["refundId"])
    assert_equal("JPY",
                 res_body["refundAmount"]["currencyCode"])
    assert_equal("100.00",
                 res_body["refundAmount"]["amount"])
    assert_equal("Refunded",
                 res_body["statusDetail"]["state"])
  end
end

