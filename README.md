# Ruby SDK for Amazon Pay V2

Amazon Pay V2 API Integration

This is forked version for [AmazonPay V2](http://amazonpaycheckoutintegrationguide.s3.amazonaws.com/amazon-pay-checkout/introduction.html).
README in Original version is [here](./README.md).

# Install

```ruby
gem 'amazon_pay', git: 'git://github.com/takahashim/amazon-pay-v2.git', branch: 'v2'
```
```
bundle install
```

## Requirements

* Ruby 2.0.0 or higher

## Quick Start

Instantiating the client:

```ruby
require 'amazon_pay'

# Your Amazon Pay keys are
# available in your Seller Central account
public_key_id = 'YOUR_PUBLIC_KEY_ID'

client = AmazonPay::ClientV2.new(
  public_key_id: public_key_id,
  private_pem_path: 'private.pem'
)
```

### Testing in Sandbox Mode

The sandbox parameter is defaulted to false if not specified:

```ruby
require 'amazon_pay'

# Your Amazon Pay keys are
# available in your Seller Central account
public_key_id = 'YOUR_PUBLIC_KEY_ID'

client = AmazonPay::ClientV2.new(
  public_key_id: public_key_id,
  sandbox: true,
  private_pem_path: 'private.pem'
)
```


### Adjusting Region and Currency Code

```ruby
require 'amazon_pay'

# Your Amazon Pay keys are
# available in your Seller Central account
public_key_id = 'YOUR_PUBLIC_KEY_ID'

client = AmazonPay::ClientV2.new(
  public_key_id: public_key_id,
  sandbox: true,
  region: :eu,
  currency_code: :gbp,
  private_pem_path: 'private.pem'
)
```

### Making an API Call

Below is an example on how to make the createCheckoutSession API call:

```ruby
require 'amazon_pay'

# Your Amazon Pay keys are
# available in your Seller Central account
public_key_id = 'YOUR_PUBLIC_KEY_ID'

client = AmazonPay::ClientV2.new(
  public_key_id: public_key_id,
  sandbox: true,
  region: :eu,
  currency_code: :gbp,
  private_pem_path: 'private.pem'
)

checkout_url = "https://example.com/user_session/amazon_login"
store_id = "YOUR_STORE_ID"

payload = {"webCheckoutDetail"=>{"checkoutReviewReturnUrl":checkout_url},
           "storeId"=>store_id}
response = client.create_checkout_session(payload)
```

(TBD)


### Response Parsing

```ruby
# These values are grabbed from the Amazon Pay
checkout_session_id = 'CHECKOUT_SESSION_ID'

response = client.get_checkout_session(checkout_session_id)

# This will return the original response body as a String
response.body

# This will return a Ruby object parsed as JSON
response.parsed_body

# This will return the status code of the response
response.code

# This will return true or false depending on the status code
response.success
```

