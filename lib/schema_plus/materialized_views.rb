require 'schema_plus/core'

module SchemaPlus
  module MaterializedViews
  end
end

require_relative 'materialized_views/version'
require_relative 'materialized_views/active_record/connection_adapters/abstract_adapter'
require_relative 'materialized_views/active_record/migration/command_recorder'
require_relative 'materialized_views/middleware'

module SchemaPlus::MaterializedViews
  module ActiveRecord
    module ConnectionAdapters
      autoload :PostgresqlAdapter, 'schema_plus/materialized_views/active_record/connection_adapters/postgresql_adapter'
    end
  end
end

SchemaMonkey.register SchemaPlus::MaterializedViews
