require 'spec_helper'
describe HstoredDocument::Storage do
  before do
    ActiveRecord::Migration.execute "drop table if exists docs"
    ActiveRecord::Migration.execute "drop table if exists items"
    ActiveRecord::Migration.create_hstored_document :docs
    ActiveRecord::Migration.create_hstored_document :items
  end

  class Doc < HstoredDocument::Storage
  end

  let(:storages) do
    [
      Doc,
      Class.new(HstoredDocument::Storage) do
        self.table_name = 'items'
      end
    ]
  end

  let(:object) do
    {
      a: "1",
      b: {
        c: "2"
      }
    }
  end

  let(:search_object) do
    {
      a: "1",
      c: {
        d: {
          x: 'y'
        }
      }
    }
  end

  let(:other_object) do
    {
      a: "1",
      c: {
        d: {
          x: 'z'
        }
      }
    }
  end

  it 'should save and find' do
    storages.each do |s|
      id = s.save(object)
      s.find(id).should == object
    end
  end

  it 'should search' do
    storages.each do |s|
      s.save(object)
      s.save(other_object)
      search_id = s.save(search_object)
      s.search('c.d', x: 'y').should == [search_object]
    end
  end
end
