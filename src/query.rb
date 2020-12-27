require_relative 'common'
require 'json'

require_relative 'lib/result_helpers'
require_relative 'lib/query_helpers'
require_relative 'conf'
require_relative 'lib/elastic_wrapper'

search_client = init_search_client

processor = ElasticWrapper.new(CONF, search_client)
output = processor.query([])

puts output.to_json
