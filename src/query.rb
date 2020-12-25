require_relative 'common'
require 'hashie/mash'
require 'json'

require_relative 'utils'
require_relative 'conf'

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

qry = prep_elastic_query(CONF[0])

results = search_client.search(index: INDEX, body: qry.to_json)
flattened = flatten_results(results)

puts flatten_results(results).to_json

# results = search_client.msearch(index: INDEX, body: [{ search: qry }])
