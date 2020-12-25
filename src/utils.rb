def flatten_bucket(bucket)
  hash =
    Hash[
      bucket.map do |k, v|
        [k, v.instance_of?(Hash) && v.key?('value') ? v['value'] : v]
      end
    ]
  key = hash.delete('key')
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
