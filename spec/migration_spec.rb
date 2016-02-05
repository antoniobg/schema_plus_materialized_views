require 'spec_helper'

class Item < ActiveRecord::Base
end

class AOnes < ActiveRecord::Base
end

class ABOnes < ActiveRecord::Base
end

describe "Migration" do

  let(:migration) { ActiveRecord::Migration }
  let(:connection) { ActiveRecord::Base.connection }
  let(:schema) { ActiveRecord::Schema }

  before(:each) do
    define_schema_and_data
  end

  context "creation" do
    it "should create correct materialized views" do
      expect(AOnes.all.collect(&:s)).to eq(%W[one_one one_two])
      expect(ABOnes.all.collect(&:s)).to eq(%W[one_one])
    end
  end

  context "duplicate creation" do
    before(:each) do
      migration.create_materialized_view('dupe_me', 'SELECT * FROM items WHERE (a=1)')
    end

    it "should raise an error by default" do
      expect {migration.create_materialized_view('dupe_me', 'SELECT * FROM items WHERE (a=2)')}.to raise_error ActiveRecord::StatementInvalid
    end
  end

  context "dropping" do
    it "should raise an error if the materialized view doesn't exist" do
      expect { migration.drop_materialized_view('doesnt_exist') }.to raise_error ActiveRecord::StatementInvalid
    end

    context "with a materialized view that exists" do
      before { migration.create_materialized_view('view_that_exists', 'SELECT * FROM items WHERE (a=1)') }

      it "should succeed" do
        migration.drop_materialized_view('view_that_exists')
        expect(connection.materialized_views).not_to include('view_that_exists')
      end
    end
  end

  describe "rollback" do
    it "properly rolls back a create_materialized_view" do
      m = Class.new ::ActiveRecord::Migration do
        define_method(:change) {
          create_materialized_view :copy, "SELECT * FROM items"
        }
      end
      m.migrate(:up)
      expect(connection.materialized_views).to include("copy")
      m.migrate(:down)
      expect(connection.materialized_views).not_to include("copy")
    end

    it "raises error for drop_materialized_view" do
      m = Class.new ::ActiveRecord::Migration do
        define_method(:change) {
          drop_materialized_view :a_ones
        }
      end
      expect { m.migrate(:down) }.to raise_error(::ActiveRecord::IrreversibleMigration)
    end
  end


  protected

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
    end
    connection.execute "insert into items (a, b, s) values (1, 1, 'one_one')"
    connection.execute "insert into items (a, b, s) values (1, 2, 'one_two')"
    connection.execute "insert into items (a, b, s) values (2, 1, 'two_one')"
    connection.execute "insert into items (a, b, s) values (2, 2, 'two_two')"

    connection.execute('REFRESH MATERIALIZED VIEW a_ones')
    connection.execute('REFRESH MATERIALIZED VIEW ab_ones')
  end
end
