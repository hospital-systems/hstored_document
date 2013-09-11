module ActiveRecord::ConnectionAdapters
  module SchemaStatements
    def create_hstored_document_storage(table_name, options = {})
      create_table(table_name) do |t|
        t.column :agg_id, 'uuid', null: false
        t.integer :parent_id
        t.integer :idx
        t.text :path
        t.hstore :attrs
        yield(t) if block_given?
      end

      quoted_table_name = quote_table_name(table_name)

      execute "alter table #{quoted_table_name} add foreign key (parent_id) references #{quoted_table_name}(id)"

      execute "create index on #{quoted_table_name} using gin(attrs)"
      execute "create index on #{quoted_table_name} (path)"
      execute "create index on #{quoted_table_name} (agg_id)"
    end
  end
end
