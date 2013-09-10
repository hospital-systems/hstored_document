module ActiveRecord::ConnectionAdapters
  module SchemaStatements
    def create_hstored_document(table_name, options = {})
      create_table(table_name, id: false, primary_key: :id) do |t|
        t.column :id, 'uuid'
        t.column :agg_id, 'uuid'
        t.column :parent_id, 'uuid'
        t.integer :idx
        t.text :path
        t.hstore :attrs
      end

      quoted_table_name = quote_table_name(table_name)
      execute "create index on #{quoted_table_name} using gin(attrs)"
      execute "create index on #{quoted_table_name} (path)"
      execute "create index on #{quoted_table_name} (agg_id)"
    end
  end
end
