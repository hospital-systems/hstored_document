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

      def delete(uuid)
        storage.where(agg_id: uuid).order('id desc').destroy_all
      end

      def delete_all(pattern)
        delete search_for_ids(pattern)
      end

      def save(uuid, hash)
        delete(uuid)
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
        construct_records(base_scope.where(agg_id: search_for_ids(pattern)))
      end

      def search_for_ids(pattern)
        _sql = pattern.delete(:_sql)
        records = destruct_hash(pattern)
        scope = storage.scoped
        sql = []

        values = []

        records.each_with_index do |record, index|
          tname = "_t#{index}"
          scope = scope.joins("JOIN #{storage.quoted_table_name} #{tname} USING (agg_id)")

          values << record[:path]
          sql << "#{tname}.path = ?"

          record[:attrs].each do |key, value|
            values << value unless value.nil?
            sql << if Array === value
                     "#{tname}.attrs -> '#{key}' IN (?)"
                   elsif value.nil?
                     "#{tname}.attrs @> '#{key}=>NULL'::hstore"
                   else
                     "#{tname}.attrs -> '#{key}' = ?"
                   end
          end
        end
        scope = scope.where(sql.join(" AND "), *values)
        if _sql
          scope = scope.where(_sql)
        end
        agg_ids = scope.pluck("DISTINCT agg_id")
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
