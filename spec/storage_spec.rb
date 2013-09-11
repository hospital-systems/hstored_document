require 'spec_helper'
describe HstoredDocument::Storage do
  before(:each) do
    ActiveRecord::Migration.execute "drop table if exists docs"
    ActiveRecord::Migration.execute "drop table if exists items"
    ActiveRecord::Migration.create_hstored_document_storage :docs
    ActiveRecord::Migration.create_hstored_document_storage :items
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

  let(:object_uuid) { SecureRandom.uuid }
  let(:search_object_uuid) { SecureRandom.uuid }
  let(:other_object_uuid) { SecureRandom.uuid }

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

  let(:object_with_nil_attribute) do
    {
      a: '1',
      b: nil
    }
  end

  it "should don't save nil attributes" do
    storages.each do |s|
      uuid = SecureRandom.uuid
      id = s.save(uuid, object_with_nil_attribute)
      x = s.find(id).should == { a: '1' }
    end
  end

  it 'should save and find' do
    storages.each do |s|
      id = s.save(object_uuid, object)
      s.find(id).should == object
    end
  end

  it 'second save should update records' do
    storages.each do |s|
      id = s.save(object_uuid, object)
      s.save(id, other_object)
      s.find(id).should == other_object
    end
  end

=begin
  it 'should search' do
    storages.each do |s|
      s.save(object_uuid, object)
      s.save(other_object_uuid, other_object)
      search_id = s.save(search_object_uuid, search_object)
      s.search('c.d', x: 'y').should == [search_object]
    end
  end
=end
  it 'should search by simple example' do
    storages.each do |s|
      s.save(search_object_uuid, search_object)
      s.search(a: '1').should =~ [search_object]
    end
  end

  it 'should search by example' do
    storages.each do |s|
      s.save(object_uuid, object)
      s.search(b: { c: '2'}).should =~ [object]
    end
  end

  it '.all should return all objects' do
    storages.each do |s|
      s.save(object_uuid, object)
      s.save(search_object_uuid, search_object)
      s.all.should =~ [search_object, object]
    end
  end
end
