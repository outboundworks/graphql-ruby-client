require_relative '../test_helper'
require 'minitest/autorun'

class MerchantChannelTest < Minitest::Test
  URL = 'https://big-and-tall-for-pets.myshopify.com/admin/api/graphql.json'

  def setup
    schema_path = File.join(File.dirname(__FILE__), '../support/fixtures/merchant_schema.json')
    schema_string = File.read(schema_path)

    @schema = GraphQLSchema.new(schema_string)
    @client = GraphQL::Client.new(
      schema: @schema,
      url: URL,
      headers: {
        'X-Shopify-Access-Token': ENV.fetch('MERCHANT_TOKEN')
      }
    )
  end

  def test_public_access_tokens
    public_access_tokens = @client.shop.public_access_tokens
    assert(public_access_tokens.count > 0)

    new_token = public_access_tokens.create(title: 'Test')
    assert_equal 32, new_token.access_token.length
    assert_equal 'Test', new_token.title

    new_token.destroy
  end
end
