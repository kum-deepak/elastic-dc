require_relative 'common'
require 'hashie/mash'
require 'json'
require_relative 'utils'

search_client = init_search_client

queries = {}

qry = {
  'size': 0,
  'aggs': { 'quarter': { 'terms': { 'field': 'quarter', "size": 1000 } } }
}

qry = {
  'size': 0,
  'aggs': {
    'month': {
      'terms': { 'field': 'month', "size": 5 },
      'aggs': {
        'avgMove': {
          'avg': {
            "script": { "source": '( doc.open.value + doc.close.value ) / 2' }
          }
        }
      }
    }
  }
}

# p.absGain += v.close - v.open;
# p.fluctuation += Math.abs(v.close - v.open);
# p.sumIndex += (v.open + v.close) / 2;
# p.avgIndex = p.sumIndex / p.count;
# p.percentageGain = p.avgIndex ? (p.absGain / p.avgIndex) * 100 : 0;
# p.fluctuationPercentage = p.avgIndex ? (p.fluctuation / p.avgIndex) * 100 : 0;

# queries["yearly-bubble-chart"] = {
qry = {
  size: 0,
  aggs: {
    "yearly-bubble-chart": {
      terms: { field: 'year', size: 1000 },
      aggs: {
        avgIndex: {
          avg: {
            "script": { "source": '( doc.open.value + doc.close.value ) / 2' }
          }
        },
        absGain: {
          sum: {
            "script": { "source": '( doc.close.value - doc.open.value )' }
          }
        },
        fluctuation: {
          sum: {
            "script": {
              "source": 'Math.abs( doc.close.value - doc.open.value )'
            }
          }
        },
        percentageGain: {
          bucket_script: {
            buckets_path: { avgIndex: 'avgIndex', absGain: 'absGain' },
            script: 'params.absGain / params.avgIndex * 100'
          }
        },
        fluctuationPercentage: {
          bucket_script: {
            buckets_path: { avgIndex: 'avgIndex', fluctuation: 'fluctuation' },
            script: 'params.fluctuation / params.avgIndex * 100'
          }
        }
      }
    }
  }
}

results = search_client.search(index: INDEX, body: qry.to_json)
flattened = flatten_results(results)

puts flatten_results(results).to_json

# results = search_client.msearch(index: INDEX, body: [{ search: qry }])
