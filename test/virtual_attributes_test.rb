# Copyright (c) 2008-2009 Pluron, Inc.

require 'test/unit'
require 'rubygems'
require 'active_record'
require File.dirname(__FILE__) + '/../init'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

class Bar < ActiveRecord::Base
end

class Foo < ActiveRecord::Base
    belongs_to :bar

    preloadable_association :bar
    preloadable_attribute :zee
end


class VirtualAttributesTest < Test::Unit::TestCase

private

    def setup_db
        ActiveRecord::Base.logger
        ActiveRecord::Schema.define(:version => 1) do
            create_table :bars do |t|
                t.column :name, :string
            end
            create_table :foos do |t|
                t.column :name, :string
                t.column :bar_id, :integer
            end
        end
    end

public

    def setup
        setup_db
    end

    def teardown_db
        ActiveRecord::Base.connection.tables.each do |table|
            ActiveRecord::Base.connection.drop_table(table)
        end
    end

    def test_preloadable_association
        b = Bar.create :name => 'Bar'
        f = Foo.create :name => 'Foo', :bar_id => b.id

        f = Foo.find_by_sql("select *, '1' as zee from foos left outer join (select id as preloaded_bar_id, name as preloaded_bar_name from bars) as bars on foos.bar_id = bars.preloaded_bar_id").first

        assert_equal "Bar", f.bar.name
        assert_equal "1", f.zee
    end

end
