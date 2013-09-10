require 'spec_helper'
describe HstoredDocument::Storage do
  before do
    ActiveRecord::Base.connection.execute %Q{
      drop table if exists docs;
      create table docs (
        id uuid primary key,
        agg_id uuid not null,
        parent_id uuid,
        idx integer,
        path varchar,
        attrs hstore
      );
    }
  end

  let(:storage) do
    Class.new(HstoredDocument::Storage) do
      self.table_name = 'docs'
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

  it 'should ' do
    id = storage.save(object)
    storage.find(id).should == object
  end
end
