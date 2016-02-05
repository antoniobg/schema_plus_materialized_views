module SchemaPlus::MaterializedViews
  module Middleware

    module Dumper
      module Tables

        # Dump views
        def after(env)
          re_matview_referent = %r{(?:(?i)FROM|JOIN) \S*\b(\S+)\b}
          env.connection.materialized_views.each do |matview_name|
            next if env.dumper.ignored?(matview_name)
            matview = MaterializedView.new(
              name: matview_name,
              definition: env.connection.materialized_view_definition(matview_name),
              indexes: env.connection.indexes(matview_name)
            )
            env.dump.tables[matview.name] = matview
            env.dump.depends(matview.name, matview.definition.scan(re_matview_referent).flatten)
          end
        end

        # quacks like a SchemaMonkey Dump::Table
        class MaterializedView < KeyStruct[:name, :definition, :indexes]
          def assemble(stream)
            heredelim = "END_VIEW_#{name.upcase}"
            stream.puts <<-ENDVIEW
  create_materialized_view "#{name}", <<-'#{heredelim}'
#{definition}
  #{heredelim}
#{format_indexes(indexes)}

            ENDVIEW
          end

          private
            def format_indexes(indexes)
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

    module Schema
      module Tables

        def self.filter_out_matviews(env)
          env.tables -= env.connection.materialized_views(env.query_name)
        end
      end
    end

    #
    # Define new middleware stacks patterned on SchemaPlus::Core's naming
    # for tables
    module Schema
      module MaterializedViews
        ENV = [:connection, :query_name, :matviews]
      end
      module MaterializedViewDefinition
        ENV = [:connection, :matview_name, :query_name, :definition]
      end
    end

    module Migration
      module CreateMaterializedView
        ENV = [:connection, :matview_name, :definition]
      end
      module DropMaterializedView
        ENV = [:connection, :matview_name]
      end
    end
  end

end
