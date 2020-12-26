require_relative 'common'
require 'hashie/mash'
require 'json'

require_relative 'utils'
require_relative 'conf'

search_client = init_search_client

flattened =
  CONF.map do |conf|
    qry = prep_elastic_query(conf)

    results = search_client.search(index: INDEX, body: qry.to_json)
    flatten_results(results)
  end

puts flattened.to_json

# results = search_client.msearch(index: INDEX, body: [{ search: qry }])
