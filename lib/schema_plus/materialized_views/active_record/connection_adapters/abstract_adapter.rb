module SchemaPlus::MaterializedViews
  module ActiveRecord
    module ConnectionAdapters
      module AbstractAdapter

        def create_materialized_view(matview_name, definition)
          SchemaMonkey::Middleware::Migration::CreateMaterializedView.start(connection: self, matview_name: matview_name, definition: definition) do |env|
            definition = env.definition
            matview_name = env.matview_name
            definition = definition.to_sql if definition.respond_to? :to_sql

            execute "CREATE MATERIALIZED VIEW #{quote_table_name(matview_name)} AS #{definition}"
          end
        end

        def drop_materialized_view(matview_name)
          SchemaMonkey::Middleware::Migration::DropMaterializedView.start(connection: self, matview_name: matview_name) do |env|
            matview_name = env.matview_name
            sql = "DROP MATERIALIZED VIEW"
            sql += " #{quote_table_name(matview_name)}"
            execute sql
          end
        end

        #####################################################################
        #
        # The functions below here are abstract; each subclass should
        # define them all. Defining them here only for reference.
        #

        # (abstract) Returns the names of all materialized views, as an array of strings
        def materialized_views(name = nil) raise "Internal Error: Connection adapter didn't override abstract function"; [] end

        # (abstract) Returns the SQL definition of a given view.  This is
        # the literal SQL would come after 'CREATE MATERIALIZED VIEW matviewname AS ' in
        # the SQL statement to create a materialized view.
        def materialized_view_definition(matview_name, name = nil) raise "Internal Error: Connection adapter didn't override abstract function"; end
      end
    end
  end
end
