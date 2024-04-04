# frozen_string_literal: true

def flatten_bucket(bucket)
  hash = Hash[bucket.map { |k, v| [k, v.instance_of?(Hash) && v.key?('value') ? v['value'] : v] }]

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

  { 'key' => key, 'value' => hash }
end

def extract_result(result)
  result['aggregations'].values.map do |res|
    groupings = { values: res['buckets'].map { |bucket| flatten_bucket(bucket) }.sort_by { |b| b['key'] } }

    # the res['meta'] will have dimId and groupId
    res['meta'].merge(groupings)
  end
end

def extract_results(raw_results)
  results = raw_results.map { |result| extract_result(result) }
  results.flatten
end

def extract_count(res)
  res['hits']['total']['value']
end
