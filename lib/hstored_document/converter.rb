module HstoredDocument
  module Converter
    def destruct_hash(hash)
      destruct_nested_hash(nil, nil, nil, nil, hash)
    end

    def destruct_nested_hash(agg_id, parent_id, idx, path, hash)
      id = SecureRandom.uuid
      agg_id ||= id
      row = {id: id, agg_id: agg_id, parent_id: parent_id, idx: idx, path: (path || ''), attrs: {}}
      records = [row]
      hash.each do |k, v|
        case v
        when Hash
          records += destruct_nested_hash(agg_id, id, nil, [path, k].compact.join('.'), v)
        when Array
          records += destruct_array(agg_id, id, [path, k].compact.join('.'), v)
        else
          row[:attrs][k.to_s] = v.to_s
        end
      end
      records
    end

    def destruct_array(agg_id, parent_id, path, array)
      records = []
      array.each_with_index do |h, index|
        records += destruct_nested_hash(agg_id, parent_id, index, path, h)
      end
      records
    end

    def construct_hash(rows)
      result = nil
      refs = {}
      rows.each do |row|
        id = row[:id]
        path = row[:path]
        key = path.split('.').last.try(:to_sym)
        attrs = row[:attrs].symbolize_keys
        parent_id = row[:parent_id]
        idx = row[:idx]
        if parent_id.nil?
          refs[id] = result = attrs
        else
          ref = refs[parent_id]
          if idx
            array = ref[key] ||= []
            refs[id] = array[idx] = attrs
          else
            refs[id] = ref[key] = attrs
          end
        end
      end
      result
    end

  end
end
