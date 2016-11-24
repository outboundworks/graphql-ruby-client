# frozen_string_literal: true

module GraphQL
  module Client
    module Query
      module HasSelectionSet
        ID_FIELD_NAME = 'id'
        INVALID_FIELD = Class.new(StandardError)
        UNDEFINED_FRAGMENT = Class.new(StandardError)

        attr_accessor :selection_set

        def add_connection(connection_name, as: nil, **arguments)
          node_field = nil

          add_field(connection_name, as: as, **arguments) do |connection|
            connection.add_field('edges') do |edges|
              edges.add_field('cursor')
              edges.add_field('node') do |node|
                node_field = node
                yield node
              end
            end

            connection.add_field('pageInfo') do |page_info|
              page_info.add_field('hasPreviousPage')
              page_info.add_field('hasNextPage')
            end
          end

          node_field
        end

        def add_field(field_name, as: nil, **arguments)
          field = resolve(field_name)
          query_field = QueryField.new(field, arguments: arguments, as: as, document: document)
          selection_set.add_field(query_field)

          query_field.add_field(ID_FIELD_NAME) if query_field.node?

          if block_given?
            yield query_field
          else
            query_field
          end
        end

        def add_fields(*field_names)
          field_names.each do |field_name|
            add_field(field_name)
          end
        end

        def add_fragment(fragment_name)
          fragment = document.fragments.fetch(fragment_name) do
            raise UNDEFINED_FRAGMENT, "a fragment named #{fragment_name} has not been defined"
          end

          selection_set.add_fragment(fragment)
        end

        private

        def resolve(field_name)
          resolver_type.fields.fetch(field_name) do
            raise INVALID_FIELD, "#{field_name} is not a valid field for #{resolver_type}"
          end
        end
      end
    end
  end
end