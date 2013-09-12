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
        sql = []

        records.each_with_index do |record, index|
          tname = "_t#{index}"
          scope = scope.joins("JOIN #{storage.quoted_table_name} #{tname} USING (agg_id)")

          sql << "#{tname}.path = '#{record[:path]}'"

          record[:attrs].each do |key, value|
            if Array === value
              v = value.map { |x| "'#{x}'" }.join(",")
              sql << "#{tname}.attrs -> '#{key}' IN (#{v})"
            else
              sql << "#{tname}.attrs -> '#{key}' = '#{value}'"
            end
          end

        end
        agg_ids = scope.where(sql.join(" AND ")).pluck(:agg_id)
        construct_records(base_scope.where(agg_id: agg_ids))
      end

      def all
        construct_records(base_scope.all)
      end

      def base_scope
        storage.order("#{storage.quoted_table_name}.id")
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
