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

def extract_result(result)
  result['aggregations'].values.map do |res|
    data =
      res['buckets']
        .map { |bucket| flatten_bucket(bucket) }
        .sort_by { |b| b[:key] }

    extracted = res['meta']
    extracted['chartId'] = extracted.delete('chart_id')
    extracted['values'] = data

    extracted
  end
end

def prep_elastic_query(entry)
  dim_conf = entry[:dimension]

  # sometimes more than one 'groups' can be associated with the same dimension
  charts = entry[:charts] ? entry[:charts] : [entry]

  agg_entries =
    charts.map do |chart_conf|
      # the meta entries are returned by Elastic as part of the results.
      # These are used to arrange the output for specific charts
      meta = chart_conf.slice(:chart_id, :layer, :name)

      # If there is a layer, ensure it has a name (as string)
      meta[:name] = "#{meta[:layer]}" if meta.key?(:layer) && !meta.key?(:name)
      aggs_entry = { meta: meta }

      aggs_entry = aggs_entry.merge(dim_conf)

      aggs_entry[:aggs] = chart_conf[:aggs] if chart_conf[:aggs]

      aggs_entry
    end

  # Make a Hash like {"0" => {...}, "1" => {...}}
  aggs =
    Hash[
      agg_entries.each_with_index.map { |aggs_entry, i| ["#{i}", aggs_entry] }
    ]

  # size: 0 instructs Elastic to not return any rows, it will ony return the aggregates
  { size: 0, aggs: aggs }
end
