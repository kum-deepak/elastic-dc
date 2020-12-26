require_relative 'common'
require 'hashie/mash'
require 'json'

require_relative 'utils'
require_relative 'conf'

search_client = init_search_client

flattened =
  CONF[4..5].map do |conf|
    prep_elastic_query(conf).map do |qry|
      results = search_client.search(index: INDEX, body: qry.to_json)
      flatten_results(results)
    end
  end

puts flattened.to_json

# results = search_client.msearch(index: INDEX, body: [{ search: qry }])
