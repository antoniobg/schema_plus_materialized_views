module SchemaPlus::MaterializedViews
  module ActiveRecord
    module ConnectionAdapters
      module PostgresqlAdapter

        def materialized_views(name = nil)
          SchemaMonkey::Middleware::Schema::MaterializedViews.start(connection: self, query_name: name, matviews: []) { |env|
            sql = <<-SQL
            SELECT matviewname
              FROM pg_matviews
            WHERE schemaname = ANY (current_schemas(false))
            AND matviewname NOT LIKE 'pg\_%'
            SQL
            sql += " AND schemaname != 'postgis'" if adapter_name == 'PostGIS'
            env.matviews += env.connection.query(sql, env.query_name).map { |row| row[0] }
          }.matviews
        end

        def materialized_view_definition(matview_name, name = nil)
          SchemaMonkey::Middleware::Schema::MaterializedViewDefinition.start(connection: self, matview_name: matview_name, query_name: name) { |env|
              result = env.connection.query(<<-SQL, name)
                SELECT pg_get_viewdef(oid)
                  FROM pg_class
                WHERE relkind = 'm'
                  AND relname = '#{env.matview_name}'
              SQL
              row = result.first
              env.definition = row.first.chomp(';').strip unless row.nil?
          }.definition
        end

        # Indexes on materialized views are ignored by the default
        # ActiveRecords Schema dumper, so we need to add them separately
        def materialized_view_indexes(connection, matview_name)
          if (indexes = connection.indexes(matview_name)).any?
            add_index_statements = indexes.map do |index|
              statement_parts = [
                ('add_index ' + index.table.inspect),
                index.columns.inspect,
                ('name: ' + index.name.inspect),
              ]
              statement_parts << 'unique: true' if index.unique

              index_lengths = (index.lengths || []).compact
              statement_parts << ('length: ' + Hash[index.columns.zip(index.lengths)].inspect) unless index_lengths.empty?

              index_orders = (index.orders || {})
              statement_parts << ('order: ' + index.orders.inspect) unless index_orders.empty?

              statement_parts << ('where: ' + index.where.inspect) if index.where

              statement_parts << ('using: ' + index.using.inspect) if index.using

              statement_parts << ('type: ' + index.type.inspect) if index.type

              '  ' + statement_parts.join(', ')
            end

            add_index_statements.sort.join("\n")
          end
        end

      end
    end
  end
end
