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

  it 'should delete object' do
    s = storages[0]
    uuid = s.save(SecureRandom.uuid, object)
    s.delete(uuid)
    s.find(uuid).should be_nil
  end

  it 'should search within array' do
    storage = storages[0]
    storage.save(SecureRandom.uuid, object_array[0])
    storage.save(SecureRandom.uuid, object_array[1])
    storage.save(SecureRandom.uuid, object_array[2])
    storage.search(a: '1', b: ['1', '2']).should =~ object_array[0..1]
  end

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

  it 'should search using multiple query params' do
    storages.each do |s|
      s.save(object_uuid, object)
      s.save(object_uuid2, object2)
      s.search(a: '1', b: { c: '2'}).should =~ [object]
    end
  end

  it '.all should return all objects' do
    storages.each do |s|
      s.save(object_uuid, object)
      s.save(search_object_uuid, search_object)
      s.all.should =~ [search_object, object]
    end
  end

  it 'should be atomically' do
    storages.each do |s|
      begin
        s.transaction do
          s.save(object_uuid, object)
          raise 'A-a-a'
        end
      rescue
        nil
      ensure
        s.all.size.should == 0
      end
    end
  end

  it '.delete_all should delete all matched objects' do
    s = storages[0]
    3.times do |i|
      s.save(SecureRandom.uuid, object_array[i])
    end
    s.delete_all({ a: '1', b: ['2', '3']})
    s.all.should =~ object_array[0..0]
  end
end
