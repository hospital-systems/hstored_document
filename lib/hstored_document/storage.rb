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
        records = destruct_hash(hash).map do |r|
          r[:agg_id] = uuid
          r
        end
        ids = {}
        records.each do |rec|
          o = storage.create(rec.merge(parent_id: ids[rec[:parent_id]]))
          ids[rec[:id]] = o.id
        end
        records.first.try(:[], :agg_id)
      end

      def find(id)
        construct(storage.where(agg_id: id))
      end

      def search(path, attributes = {})
        scope = storage.where(path: path)
        attributes.each do |key, value|
          scope = scope.where("attrs -> '#{key}' = '#{value}'")
        end
        agg_ids = scope.pluck(:agg_id)
        storage.where(agg_id: agg_ids).group_by(&:agg_id).map do |_, group|
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
