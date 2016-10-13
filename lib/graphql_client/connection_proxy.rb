module GraphQL
  module Client
    class ConnectionProxy
      include Enumerable

      attr_reader :arguments, :objects, :parent

      def initialize(*fields, field:, parent:, parent_field:, client:, data: {}, includes: {}, **arguments)
        @fields = fields.map(&:to_s)
        @field = field
        @parent = parent
        @parent_field = parent_field
        @client = client
        @data = data
        @includes = includes
        @schema = @client.schema
        @type = @field.base_type
        @objects = []
        @loaded = false
        @arguments = arguments
      end

      def create(attributes = {})
        type = @type.node_type

        type_name = type.name.dup
        type_name[0] = type_name[0].downcase

        mutation = Query::MutationDocument.new(@client.schema) do |m|
          m.add_field("#{type_name}Create", input: attributes) do |field|
            field.add_field(type_name) do |connection_type|
              connection_type.add_fields(*type.scalar_fields.names)
            end

            field.add_field('userErrors') do |errors|
              errors.add_fields('field', 'message')
            end
          end
        end

        response = @client.query(mutation)
        attributes = response_object(response).fetch(type_name)

        ObjectProxy.new(field: @field, data: attributes, client: @client)
      end

      def cursor
        connection_edges(@response.data).last.fetch('cursor')
      end

      def each
        load_page unless @loaded

        @objects.each do |node|
          yield ObjectProxy.new(
            client: @client,
            data: node,
            field: @field,
            includes: @includes,
          )
        end
      end

      def length
        entries.length
      end

      def next_page?
        @response.data.dig(*parent.query_path, @field.name, 'pageInfo', 'hasNextPage')
      end

      def proxy_path
        [].tap do |parents|
          parents << @parent.proxy_path if @parent
          parents << @parent if @parent
        end.flatten
      end

      private

      def rebuild_query(query = root)
        proxy_path.each do |proxy|
          query = query.add_field(proxy.field.name, proxy.arguments)
        end

        query
      end

      def connection_query(after: nil)
        raise "Connection field \"#{@field.name}\" requires a selection set" if @fields.empty? && @includes.empty?

        args = {}

        parent_type = if @parent.type.is_a? GraphQLSchema::Types::Connection
          @parent.type.node_type
        else
          @parent.type
        end

        query = Query::QueryDocument.new(@schema)

        if @parent.loaded && @parent.id && @schema.query_root.fields.fetch(parent_type.name.downcase).args.key?('id')
          # We can shortcut this query and base it off of an already known node object
          args[:id] = @parent.id

          connection_args = { first: @arguments.fetch(:first, @client.config.per_page) }
          connection_args[:after] = after if after

          query.add_field(parent_type.name.downcase, **args) do |node|
            node.add_connection(@field.name, **connection_args) do |connection|
              connection.add_field('id') if @type.node_type.fields.field? 'id'
              connection.add_fields(*@fields)

              if @includes.any?
                add_includes(connection, @includes)
              end
            end
          end
        else
          connection_args = { first: @arguments.fetch(:first, @client.config.per_page) }
          connection_args[:after] = after if after

          query_leaf = rebuild_query(query)
          query_leaf.add_connection(@field.name, **connection_args) do |connection|
            connection.add_field('id') if @type.node_type.fields.field? 'id'
            connection.add_fields(*@fields)

            if @includes.any?
              add_includes(connection, @includes)
            end
          end
        end

        query
      end

      def add_includes(connection, includes)
        includes.each do |key, values|
          if connection.resolver_type.fields[key.to_s].connection?
            connection.add_connection(
              key.to_s,
              first: @arguments.fetch(:first, @client.config.per_page)
            ) do |subconnection|
              values.each do |field|
                if field.is_a? String
                  subconnection.add_field(field)
                else
                  add_includes(subconnection, field)
                end
              end
            end
          else
            connection.add_field(key.to_s) do |subfield|
              values.each do |field|
                if field.is_a? String
                  subfield.add_field(field)
                else
                  add_includes(subfield, field)
                end
              end
            end
          end
        end
      end

      def connection_edges(response_data)
        response_data.dig(*parent.query_path, @field.name, 'edges')
      end

      def fetch_page
        @response = if arguments.key?(:after)
          @client.query(connection_query(after: arguments[:after]))
        else
          @client.query(connection_query)
        end

        edges = connection_edges(@response.data)
        @objects += nodes(edges)

        if @client.config.fetch_all_pages
          while next_page?
            @response = @client.query(connection_query(after: cursor))

            edges = connection_edges(@response.data)
            @objects += nodes(edges)
          end
        end
      end

      def load_page
        if @data.empty?
          fetch_page
        else
          @objects += nodes(@data['edges'])
        end

        @loaded = true
      end

      def nodes(edges_data)
        edges_data.map { |edge| edge.fetch('node') }
      end

      def response_object(response)
        object = response.data.keys.first
        response.data.fetch(object)
      end
    end
  end
end
