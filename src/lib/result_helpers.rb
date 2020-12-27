def flatten_bucket(bucket)
  hash =
    Hash[
      bucket.map do |k, v|
        [k, v.instance_of?(Hash) && v.key?('value') ? v['value'] : v]
      end
    ]

  key = hash.delete('key')

  # If key is a date, Elastic returns numeric for key and JSON encoded string for key_as_string
  # "key": 1338508800000,
  # "key_as_string": "2012-06-01T00:00:00.000Z",
  # Currently we prefer to use JSON formatted string
  key = hash.delete('key_as_string') if hash.key? 'key_as_string'

  if hash.key?('only_me')
    # Set agg name to only_me, if you want that itself as value
    hash = hash['only_me']
  else
    # only doc_count will be there if no explicit aggs were provided, the doc_count becomes value in such cases
    hash = hash['doc_count'] if hash.keys.size == 1
  end

  { key: key, value: hash }
end

def retrieve_value_accessor(meta, value_accessors)
  if meta.key?('value_accessor')
    value_accessors[meta['value_accessor'].to_i]
  else
    nil
  end
end

def extract_result(result, value_accessors)
  result['aggregations'].values.map do |res|
    data =
      res['buckets']
        .map { |bucket| flatten_bucket(bucket) }
        .sort_by { |b| b[:key] }

    extracted = res['meta']
    extracted['chartId'] = extracted.delete('chart_id')

    # value_accessor
    value_accessor = retrieve_value_accessor(res['meta'], value_accessors)
    if !value_accessor.nil?
      data.each { |d| d[:_value] = value_accessor.call(d) }
    else
      data.each { |d| d[:_value] = d[:value] }
    end

    extracted['values'] = data

    extracted
  end
end
