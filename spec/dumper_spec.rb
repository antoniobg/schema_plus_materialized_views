require 'spec_helper'

class Item < ActiveRecord::Base
end

describe "Dumper" do

  let(:schema) { ActiveRecord::Schema }

  let(:migration) { ActiveRecord::Migration }

  let(:connection) { ActiveRecord::Base.connection }

  before(:each) do
    define_schema_and_data
  end

  it "should include view definitions" do
    expect(dump).to match(matview_re("a_ones", /SELECT .*b.*,.*s.* FROM .*items.* WHERE \(?.*a.* = 1\)?/mi))
    expect(dump).to match(matview_re("ab_ones", /SELECT .*s.* FROM .*a_ones.* WHERE \(?.*b.* = 1\)?/mi))
  end

  it "should include index definitions" do
    expect(dump).to match(matview_index_re("a_ones", /\[\"b\", \"s\"\].+/mi))
    expect(dump).to match(matview_index_re("ab_ones", /\[\"s\"\].+/mi))
  end

  it "should include materialized views in dependency order" do
    expect(dump).to match(%r{create_table "items".*create_materialized_view "a_ones".*create_materialized_view "ab_ones"}m)
  end

  it "should not include materialized views listed in ignore_tables" do
    dump(ignore_tables: /b_/) do |dump|
      expect(dump).to match(matview_re("a_ones", /SELECT .*b.*,.*s.* FROM .*items.* WHERE \(?.*a.* = 1\)?/mi))
      expect(dump).not_to match(%r{"ab_ones"})
    end
  end

  protected

  def matview_re(name, re)
    heredelim = "END_VIEW_#{name.upcase}"
    %r{create_materialized_view "#{name}", <<-'#{heredelim}'\n\s*#{re}\s*\n *#{heredelim}$}mi
  end

  def matview_index_re(name, re)
    %r{add_index "#{name}", #{re}\s*}mi
  end

  def define_schema_and_data
    connection.materialized_views.each do |matview| connection.drop_materialized_view matview end
    connection.tables.each do |table| connection.drop_table table, cascade: true end

    schema.define do

      create_table :items, :force => true do |t|
        t.integer :a
        t.integer :b
        t.string  :s
      end

      create_materialized_view :a_ones, Item.select('b, s').where(:a => 1)
      create_materialized_view :ab_ones, "select s from a_ones where b = 1"
      add_index :a_ones,  [:b, :s]
      add_index :ab_ones, :s
    end
    connection.execute "insert into items (a, b, s) values (1, 1, 'one_one')"
    connection.execute "insert into items (a, b, s) values (1, 2, 'one_two')"
    connection.execute "insert into items (a, b, s) values (2, 1, 'two_one')"
    connection.execute "insert into items (a, b, s) values (2, 2, 'two_two')"

    connection.execute('REFRESH MATERIALIZED VIEW a_ones')
    connection.execute('REFRESH MATERIALIZED VIEW ab_ones')
  end

  def dump(opts={})
    StringIO.open { |stream|
      ActiveRecord::SchemaDumper.ignore_tables = Array.wrap(opts[:ignore_tables])
      ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, stream)
      yield stream.string if block_given?
      stream.string
    }
  end

end
