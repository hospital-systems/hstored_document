module HstoredDocument
  class Storage
    class << self
      include HstoredDocument::Converter

      def table_name=(tname)
        @storage = Class.new(ActiveRecord::Base) do
          self.table_name = tname
          serialize :attrs, ActiveRecord::Coders::Hstore
        end
      end

      def save(hash)
        records = destruct_hash(hash)
        records.each do |rec|
          @storage.create rec do |object|
            object.id = rec[:id]
          end
        end
        records.first.try(:[], :agg_id)
      end

      def find(id)
        construct(@storage.where(agg_id: id))
      end

      def search(path, attributes = {})
        scope = @storage.where(path: path)
        attributes.each do |key, value|
          scope = scope.where("attrs -> '#{key}' = '#{value}'")
        end
        agg_ids = scope.pluck(:agg_id)
        @storage.where(agg_id: agg_ids).group_by(&:agg_id).map do |_, group|
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
