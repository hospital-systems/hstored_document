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

  let(:storage) do
      Doc
  end

  let(:anonymous_storage) do
    Class.new(HstoredDocument::Storage) do
      self.table_name = 'items'
    end
  end

  let(:object_uuid) { SecureRandom.uuid }
  let(:object_uuid2) { SecureRandom.uuid }
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

  let(:object2) do
    {
      a: "2",
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

  let(:object_array) do
    [{
      b: '1',
      a: '1'
    },
    {
      b: '2',
      a: '1'
    },
    {
      b: '3',
      a: '1'
    }]
  end

  it "should save and find with anonymous storage" do
    id = anonymous_storage.save(object_uuid, object)
    anonymous_storage.find(id).should == object
  end

  it "should don't save nil attributes" do
    uuid = SecureRandom.uuid
    id = storage.save(uuid, object_with_nil_attribute)
    x = storage.find(id).should == { a: '1' }
  end

  it 'should save and find' do
    id = storage.save(object_uuid, object)
    storage.find(id).should == object
  end

  it 'second save should update records' do
    id = storage.save(object_uuid, object)
    storage.save(id, other_object)
    storage.find(id).should == other_object
  end

  it 'should delete object' do
    uuid = storage.save(SecureRandom.uuid, object)
    storage.delete(uuid)
    storage.find(uuid).should be_nil
  end

  it 'should search within array' do
    storage.save(SecureRandom.uuid, object_array[0])
    storage.save(SecureRandom.uuid, object_array[1])
    storage.save(SecureRandom.uuid, object_array[2])
    storage.search(a: '1', b: ['1', '2']).should =~ object_array[0..1]
  end

  it 'should search by simple example' do
    storage.save(search_object_uuid, search_object)
    storage.search(a: '1').should =~ [search_object]
  end

  it 'should search by example' do
    storage.save(object_uuid, object)
    storage.search(b: { c: '2'}).should =~ [object]
  end

  it 'should search using multiple query params' do
    storage.save(object_uuid, object)
    storage.save(object_uuid2, object2)
    storage.search(a: '1', b: { c: '2'}).should =~ [object]
  end

  it '.all should return all objects' do
    storage.save(object_uuid, object)
    storage.save(search_object_uuid, search_object)
    storage.all.should =~ [search_object, object]
  end

  it 'should be atomically' do
    begin
      storage.transaction do
        storage.save(object_uuid, object)
        raise 'A-a-a'
      end
    rescue
      nil
    ensure
      storage.all.size.should == 0
    end
  end

  it '.delete_all should delete all matched objects' do
    3.times do |i|
      storage.save(SecureRandom.uuid, object_array[i])
    end
    storage.delete_all({ a: '1', b: ['2', '3']})
    storage.all.should =~ object_array[0..0]
  end
end
