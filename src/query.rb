require_relative 'lib/common'
require 'hashie/mash'
require 'json'

require_relative 'lib/result_helpers'
require_relative 'lib/query_helpers'
require_relative 'conf'

search_client = init_search_client

value_accessors = []
prepared_queries = CONF.map { |conf| prep_elastic_query(conf, value_accessors) }

raw_results =
  search_client.msearch(
    index: INDEX,
    body: prepared_queries.map { |q| { search: q } }
  )

extracted =
  raw_results['responses'].map do |result|
    extract_result(result, value_accessors)
  end.flatten

formatted =
  extracted
    .group_by { |e| e['chartId'] }
    .map do |chart_id, results|
      if results.size == 1 && !results[0].key?('layer')
        results[0]
      else
        # the chart expects layers, prepare the data accordingly
        layers = results.sort_by { |e| e['layer'] }

        {
          'chartId' => chart_id,
          'values' =>
            layers.map { |r| { 'name' => r['name'], 'rawData' => r['values'] } }
        }
      end
    end

# extracted =
#   CONF[4..5].map do |conf|
#     qry = prep_elastic_query(conf)
#     results = search_client.search(index: INDEX, body: qry.to_json)
#     extract_result(results)
#     pp search_client.msearch(index: INDEX, body: [{ search: qry }])
#   end

puts formatted.to_json

# results = search_client.msearch(index: INDEX, body: [{ search: qry }])
