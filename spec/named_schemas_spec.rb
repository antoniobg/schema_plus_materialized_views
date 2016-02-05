require 'spec_helper'

describe "with multiple schemas" do
  def connection
    ActiveRecord::Base.connection
  end

  before(:each) do
    newdb = case connection.adapter_name
            when /^postgresql/i then "CREATE SCHEMA schema_plus_materialized_views_test2"
            end
    begin
      ActiveRecord::Base.connection.execute newdb
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.message =~ /already/
    end

    class User < ::ActiveRecord::Base ; end
  end

  before(:each) do
    ActiveRecord::Schema.define do
      create_table :users, :force => true do |t|
        t.string :login
      end
    end

    connection.execute 'DROP TABLE IF EXISTS schema_plus_materialized_views_test2.users'
    connection.execute 'CREATE TABLE schema_plus_materialized_views_test2.users (id ' + case connection.adapter_name
          when /^postgresql/i then "serial primary key"
          end + ", login varchar(255))"
  end

  context "with materialized views in each schema" do
    around(:each) do  |example|
      begin
        example.run
      ensure
        connection.execute 'DROP MATERIALIZED VIEW schema_plus_materialized_views_test2.mymatview' rescue nil
        connection.execute 'DROP MATERIALIZED VIEW mymatview' rescue nil
      end
    end

    before(:each) do
      connection.materialized_views.each { |matview| connection.drop_materialized_view matview }
      connection.execute 'CREATE MATERIALIZED VIEW schema_plus_materialized_views_test2.mymatview AS SELECT * FROM users'
    end

    it "should not find materialized views in other schema" do
      expect(connection.materialized_views).to be_empty
    end

    it "should find materialized views in this schema" do
      connection.execute 'CREATE MATERIALIZED VIEW mymatview AS SELECT * FROM users'
      expect(connection.materialized_views).to eq(['mymatview'])
    end
  end

  context "when using PostGIS", :postgresql => :only do
    before(:all) do
      begin
        connection.execute "CREATE SCHEMA postgis"
      rescue ActiveRecord::StatementInvalid => e
        raise unless e.message =~ /already exists/
      end
    end

    around(:each) do |example|
      begin
        connection.execute "SET search_path to '$user','public','postgis'"
        example.run
      ensure
        connection.execute "SET search_path to '$user','public'"
      end
    end

    before(:each) do
      allow(connection).to receive(:adapter_name).and_return('PostGIS')
    end

    it "should hide views in postgis schema" do
      begin
        connection.create_materialized_view "postgis.hidden", "select 1"
        connection.create_materialized_view :mymatview, "select 2"
        expect(connection.materialized_views).to eq(["mymatview"])
      ensure
        connection.execute 'DROP MATERIALIZED VIEW postgis.hidden' rescue nil
        connection.execute 'DROP MATERIALIZED VIEW mymatview' rescue nil
      end
    end
  end

end
