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

  let(:object) do
    {
      a: "1",
      b: {
        c: "2"
      }
    }
  end

  let(:object_with_time) do
    {
      value: '123',
      created_at: 1.day.ago.to_s,
    }
  end

  let(:object_with_time_second) do
    {
      value: '123',
      created_at: 1.week.ago.to_s,
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

  def save(object)
    storage.save(SecureRandom.uuid, object)
  end

  it "should save and find with anonymous storage" do
    id = anonymous_storage.save(SecureRandom.uuid, object)
    anonymous_storage.find(id).should == object
  end

  it "should don't save nil attributes" do
    id = save object_with_nil_attribute
    x = storage.find(id).should == { a: '1', b: nil }
  end

  it 'should save and find' do
    id = save(object)
    storage.find(id).should == object
  end

  it 'second save should update records' do
    id = save(object)
    storage.save(id, other_object)
    storage.find(id).should == other_object
  end

  it 'should delete object' do
    uuid = save(object)
    storage.delete(uuid)
    storage.find(uuid).should be_nil
  end

  it 'should search within array' do
    save(object_array[0])
    save(object_array[1])
    save(object_array[2])
    storage.search(a: '1', b: ['1', '2']).should =~ object_array[0..1]
  end

  it 'should search by simple example' do
    save(search_object)
    storage.search(a: '1').should =~ [search_object]
  end

  it 'should search by example' do
    save(object)
    storage.search(b: { c: '2'}).should =~ [object]
  end

  it 'should search using multiple query params' do
    save(object)
    save(object2)
    storage.search(a: '1', b: { c: '2'}).should =~ [object]
  end

  it '.all should return all objects' do
    save(object)
    save(search_object)
    storage.all.should =~ [search_object, object]
  end

  it 'should search by nil value' do
    save(object_with_nil_attribute)
    storage.search(b: nil).should =~ [object_with_nil_attribute]
    storage.search(b: nil, a: '1').should =~ [object_with_nil_attribute]
  end

  it 'should be atomically' do
    begin
      storage.transaction do
        save(object)
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
      save(object_array[i])
    end
    storage.delete_all({ a: '1', b: ['2', '3']})
    storage.all.should =~ object_array[0..0]
  end

  let(:danger_object) do
    {
      a: "'1",
      b: "2;drop",
      c: "3--"
    }
  end

  it 'should escape search values' do
    save(danger_object)
    storage.search(a: "'1").should =~ [danger_object]
    storage.search(b: "2;drop").should =~ [danger_object]
    storage.search(c: "3--").should =~ [danger_object]
  end

  it 'should search by sql' do
    save(object_with_time)
    save(object_with_time_second)
    storage.search(_sql: ["(docs.attrs->'created_at')::timestamp > ?", 2.days.ago]).should =~ [object_with_time]
    storage.search(_sql: ["(docs.attrs->'created_at')::timestamp > :now", { now: 2.days.ago }]).should =~ [object_with_time]
  end
end

