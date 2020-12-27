require_relative 'lib/common'
require 'json'

require_relative 'lib/result_helpers'
require_relative 'lib/query_helpers'
require_relative 'conf'

search_client = init_search_client

value_accessors = []
prepared_queries =
  CONF[:charts].map { |conf| prep_elastic_query(conf, value_accessors) }

raw_results =
  search_client.msearch(
    index: INDEX,
    body: prepared_queries.map { |q| { search: q } }
  )

LOGGER.info("Query took: #{raw_results['took']} ms")

extracted_results = extract_results(raw_results, value_accessors)
formatted = format_results(extracted_results)

output = {
  "selectedRecords": 6724,
  "totalRecords": 6724,
  "chartData": formatted
}

puts output.to_json
