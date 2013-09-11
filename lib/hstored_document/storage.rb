module HstoredDocument
  class Storage
    class << self
      include HstoredDocument::Converter

      def storage
        @table_name ||= name.tableize
        table_name = @table_name
        @storage ||= Class.new(ActiveRecord::Base) do
          self.table_name = table_name
          serialize :attrs, ActiveRecord::Coders::Hstore
        end
      end

      def table_name=(tname)
        @table_name = tname
      end

      def save(uuid, hash)
        storage.where(agg_id: uuid).order('id desc').destroy_all
        records = destruct_hash(hash)
        ids = {}
        transaction do
          records.each do |rec|
            o = storage.create(rec.merge(agg_id: uuid, parent_id: ids[rec[:parent_id]]))
            ids[rec[:id]] = o.id
          end
        end
        uuid
      end

      def find(id)
        construct(base_scope.where(agg_id: id))
      end

      def search(pattern)
        records = destruct_hash(pattern)
        scope = base_scope
        records.each do |record|
          score = scope.where(path: record[:path])
          record[:attrs].each do |key, value|
            scope = scope.where("attrs -> '#{key}' = '#{value}'")
          end
        end
        agg_ids = scope.pluck(:agg_id)
        construct_records(base_scope.where(agg_id: agg_ids))
      end

      def all
        construct_records(base_scope.all)
      end

      def base_scope
        storage.order('id')
      end

      def transaction(&block)
        storage.transaction(&block)
      end

      def construct_records(records)
        records.group_by(&:agg_id).map do |_, group|
          construct(group)
        end
      end

      def construct(records)
        rows = records.map do |item|
          item.attributes.symbolize_keys
        end
        construct_hash(rows)
      end
    end
  end
end
