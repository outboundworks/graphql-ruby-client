require 'test_helper'

module GraphQL
  module Client
    module Query
      class AddInlineFragmentTest < Minitest::Test
        def setup
          @schema = GraphQLSchema.load_schema(fixture_path('merchant_schema.json'))
          @document = Document.new(@schema)

          field_defn = @schema.query_root.fields.fetch('shop')
          @field = Field.new(field_defn, document: @document, arguments: {})
        end

        def test_add_inline_fragment_yields_inline_fragment
          inline_fragment_object = nil

          inline_fragment = @field.add_inline_fragment('Shop') do |f|
            inline_fragment_object = f
          end

          assert_equal inline_fragment_object, inline_fragment
        end

        def test_add_inline_fragment_creates_inline_fragment_with_explicit_type
          inline_fragment = @field.add_inline_fragment('Shop')

          assert_equal @schema['Shop'], inline_fragment.type
          assert_equal [inline_fragment], @field.selection_set.inline_fragments
        end

        def test_add_inline_fragment_creates_inline_fragment_with_explicit_interface_type
          inline_fragment = @field.add_inline_fragment('Node')

          assert_equal @schema['Node'], inline_fragment.type
          assert_equal [inline_fragment], @field.selection_set.inline_fragments
        end

        def test_add_inline_fragment_creates_inline_fragment_with_implicit_type
          inline_fragment = @field.add_inline_fragment

          assert_equal @schema['Shop'], inline_fragment.type
          assert_equal [inline_fragment], @field.selection_set.inline_fragments
        end

        def test_add_inline_fragment_raises_exception_for_invalid_target_type
          assert_raises AddInlineFragment::INVALID_FRAGMENT_TARGET do |e|
            @field.add_inline_fragment('Image')

            assert_equal "invalid target type 'Image' for fragment of type 'Shop'", e.message
          end
        end
      end
    end
  end
end
