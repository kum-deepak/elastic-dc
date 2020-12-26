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

def flatten_results(results)
  chart_id = results['aggregations'].keys.first
  res = results['aggregations'][chart_id]
  data =
    res['buckets']
      .map { |bucket| flatten_bucket(bucket) }
      .sort_by { |b| b[:key] }

  flattened = { "chartId": res['meta']['chartId'], "values": data }

  flattened[:layer] = res['meta']['layer'] if res['meta']['layer']

  flattened
end

def prep_elastic_query(chart_conf)
  if chart_conf[:charts]
    chart_conf[:charts].each_with_index.map do |layer, i|
      meta = { chartId: layer[:chart_id] }
      meta[:layer] = layer[:layer] if layer.key? :layer
      aggs_conf = { meta: meta }

      aggs_conf = aggs_conf.merge(chart_conf[:dimension])

      aggs_conf[:aggs] = layer[:aggs] if layer[:aggs]

      { size: 0, aggs: { "#{i}" => aggs_conf } }
    end
  else
    aggs_conf = { meta: { chartId: chart_conf[:chart_id] } }

    aggs_conf = aggs_conf.merge(chart_conf[:dimension])

    aggs_conf[:aggs] = chart_conf[:aggs] if chart_conf[:aggs]

    [{ size: 0, aggs: { '0' => aggs_conf } }]
  end
end
