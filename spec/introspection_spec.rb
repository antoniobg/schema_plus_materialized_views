require 'spec_helper'

class Item < ActiveRecord::Base
end

describe "Introspection" do

  let(:schema) { ActiveRecord::Schema }

  let(:migration) { ActiveRecord::Migration }

  let(:connection) { ActiveRecord::Base.connection }

  before(:each) do
    define_schema_and_data
  end

  it "should list all views" do
    expect(connection.materialized_views.sort).to eq(%W[a_ones ab_ones])
    expect(connection.materialized_view_definition('a_ones')).to match(%r{^SELECT .*b.*,.*s.* FROM .*items.* WHERE .*a.* = 1}mi)
    expect(connection.materialized_view_definition('ab_ones')).to match(%r{^SELECT .*s.* FROM .*a_ones.* WHERE .*b.* = 1}mi)
  end

  it "should ignore materialized views named pg_*", postgresql: :only do
    begin
      migration.create_materialized_view :pg_dummy_internal, "select 1"
      expect(connection.materialized_views.sort).to eq(%W[a_ones ab_ones])
    ensure
      migration.drop_materialized_view :pg_dummy_internal
    end
  end

  it "should not be listed as a table" do
    expect(connection.tables).not_to include('a_ones')
    expect(connection.tables).not_to include('ab_ones')
  end

  it "should introspect definition" do
    expect(connection.materialized_view_definition('a_ones')).to match(%r{^SELECT .*b.*,.*s.* FROM .*items.* WHERE .*a.* = 1}mi)
    expect(connection.materialized_view_definition('ab_ones')).to match(%r{^SELECT .*s.* FROM .*a_ones.* WHERE .*b.* = 1}mi)
  end

  protected

  def define_schema_and_data
    connection.materialized_views.each do |view| connection.drop_materialized_view view end
    connection.tables.each do |table| connection.drop_table table, cascade: true end

    schema.define do

      create_table :items, :force => true do |t|
        t.integer :a
        t.integer :b
        t.string  :s
      end

      create_materialized_view :a_ones, Item.select('b, s').where(:a => 1)
      create_materialized_view :ab_ones, "select s from a_ones where b = 1"
    end
    connection.execute "insert into items (a, b, s) values (1, 1, 'one_one')"
    connection.execute "insert into items (a, b, s) values (1, 2, 'one_two')"
    connection.execute "insert into items (a, b, s) values (2, 1, 'two_one')"
    connection.execute "insert into items (a, b, s) values (2, 2, 'two_two')"

    connection.execute('REFRESH MATERIALIZED VIEW a_ones')
    connection.execute('REFRESH MATERIALIZED VIEW ab_ones')
  end

end
