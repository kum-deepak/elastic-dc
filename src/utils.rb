def flatten_bucket(bucket)
  hash =
    Hash[
      bucket.map do |k, v|
        [k, v.instance_of?(Hash) && v.key?('value') ? v['value'] : v]
      end
    ]
  key = hash.delete('key')

  if hash.key?('only_me')
    # Set agg name to only_me, if you want that itself as value
    hash = hash['only_me']
  else
    # only doc_count will be there if no explicit aggs were provided, the doc_count becomes value in suc cases
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

  { "chartId": chart_id, "values": data }
end

def prep_elastic_query(chart_conf)
  aggs_conf = chart_conf[:dimension]
  aggs_conf = aggs_conf.merge({ aggs: chart_conf[:aggs] }) if chart_conf[:aggs]

  { size: 0, aggs: { chart_conf[:chart_id] => aggs_conf } }
end
