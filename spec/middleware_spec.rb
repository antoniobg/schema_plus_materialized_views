require 'spec_helper'

module TestMiddleware
  module Middleware

    module Schema
      module MaterializedViews
        SPY = []
        def after(env)
          SPY << env.to_hash.except(:connection)
        end
      end
      module MaterializedViewDefinition
        SPY = []
        def after(env)
          SPY << env.to_hash.except(:connection)
        end
      end
    end

    module Migration
      module CreateMaterializedView
        SPY = []
        def after(env)
          SPY << env.to_hash.except(:connection)
        end
      end
      module DropMaterializedView
        SPY = []
        def after(env)
          SPY << env.to_hash.except(:connection)
        end
      end
    end

  end
end

SchemaMonkey.register TestMiddleware

context SchemaPlus::MaterializedViews::Middleware do

  let(:schema) { ActiveRecord::Schema }
  let(:migration) { ActiveRecord::Migration }
  let(:connection) { ActiveRecord::Base.connection }

  before(:each) do
    schema.define do
      create_table :items, force: true do |t|
        t.integer :a
      end
      create_materialized_view 'a_items', "select a from items"
    end
  end

  context TestMiddleware::Middleware::Schema::MaterializedViews do
    it "calls middleware" do
      expect(spy_on {connection.materialized_views 'qn'}).to eq({
        #connection: connection,
        matviews: ['a_items'],
        query_name: 'qn'
      })
    end
  end

  context TestMiddleware::Middleware::Schema::MaterializedViewDefinition do
    it "calls middleware" do
      spied = spy_on {connection.materialized_view_definition('a_items', 'qn')}
      expect(spied[:matview_name]).to eq('a_items')
      expect(spied[:definition]).to match(%r{SELECT .*a.* FROM .*items.*}mi)
      expect(spied[:query_name]).to eq('qn')
    end
  end

  context TestMiddleware::Middleware::Migration::CreateMaterializedView do
    it "calls middleware" do
      expect(spy_on {migration.create_materialized_view('newview', 'select a from items')}).to eq({
        matview_name: 'newview',
        definition: 'select a from items'
      })
    end
  end

  context TestMiddleware::Middleware::Migration::DropMaterializedView do
    it "calls middleware" do
      expect(spy_on {migration.drop_materialized_view('a_items')}).to eq({
        matview_name: 'a_items'
      })
    end
  end


  private

  def spy_on
    spy = described_class.const_get :SPY
    spy.clear
    yield
    spy.first
  end

end
