require 'test_helper'

module GraphQL
  module Client
    class GraphObjectQueryTransformingTest < Minitest::Test
      COLLECTION_ID = 'gid://shopify/Collection/67890'
      COLLECTION_CURSOR = 'collection-cursor'
      PRODUCT_ID = 'gid://shopify/Product/72727'
      VARIANTS_CURSOR = 'variants-cursor'
      GRAPH_FIXTURE = {
        data: {
          shop: {
            name: 'my-shop',
            privacyPolicy: {
              body: 'Text'
            },
            collections: {
              pageInfo: {
                hasPreviousPage: false,
                hasNextPage: true
              },
              edges: [{
                cursor: COLLECTION_CURSOR,
                node: {
                  id: COLLECTION_ID,
                  handle: 'fancy-poles'
                }
              }]
            },
            products: {
              pageInfo: {
                hasPreviousPage: false,
                hasNextPage: true
              },
              edges: [{
                cursor: 'product-cursor',
                node: {
                  id: PRODUCT_ID,
                  handle: 'some-product',
                  variants: {
                    pageInfo: {
                      hasPreviousPage: false,
                      hasNextPage: true
                    },
                    edges: [{
                      cursor: VARIANTS_CURSOR,
                      node: {
                        id: PRODUCT_ID,
                        title: 'large'
                      }
                    }]
                  }
                }
              }]
            }
          }
        }
      }

      def setup
        @schema = GraphQLSchema.new(schema_fixture('schema.json'))
        @graphql_schema = GraphQL::Schema::Loader.load(schema_fixture('schema.json'))

        @base_query = Query::QueryDocument.new(@schema) do |root|
          root.add_field('shop') do |shop|
            shop.add_field('name')
            shop.add_field('privacyPolicy') do |address|
              address.add_field('body')
            end
            shop.add_connection('collections', first: 1) do |collections|
              collections.add_field('handle')
            end
            shop.add_connection('products', first: 1) do |products|
              products.add_field('handle')
              products.add_connection('variants', first: 1) do |variants|
                variants.add_field('title')
              end
            end
          end
        end

        data = GRAPH_FIXTURE[:data].to_json
        @graph = GraphObject.new(data: JSON.parse(data), query: @base_query)
      end

      def test_nodes_can_generate_a_query_to_refetch_themselves
        query_string = <<~QUERY
          query {
            node(id: "#{COLLECTION_ID}") {
              ... on Collection {
                id
                handle
              }
            }
          }
        QUERY

        assert_equal query_string, @graph.shop.collections.to_a[0].refetch_query.to_query
        assert_valid_query query_string, @graphql_schema
      end

      def test_arrays_of_nodes_can_generate_a_query_to_fetch_the_next_page
        query_string = <<~QUERY
          query {
            shop {
              collections(first: 1, after: "#{COLLECTION_CURSOR}") {
                edges {
                  cursor
                  node {
                    id
                    handle
                  }
                }
                pageInfo {
                  hasPreviousPage
                  hasNextPage
                }
              }
            }
          }
        QUERY

        assert_equal query_string, @graph.shop.collections.next_page_query.to_query
        assert_valid_query query_string, @graphql_schema
      end

      def test_arrays_of_nodes_nested_under_a_truncated_query_to_fetch_their_next_page
        query_string = <<~QUERY
          query {
            node(id: "#{PRODUCT_ID}") {
              ... on Product {
                id
                variants(first: 1, after: "#{VARIANTS_CURSOR}") {
                  edges {
                    cursor
                    node {
                      id
                      title
                    }
                  }
                  pageInfo {
                    hasPreviousPage
                    hasNextPage
                  }
                }
              }
            }
          }
        QUERY

        assert_equal query_string, @graph.shop.products.to_a[0].variants.next_page_query.to_query
        assert_valid_query query_string, @graphql_schema
      end
    end
  end
end
