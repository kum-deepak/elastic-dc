require 'rack'

require_relative 'result_helpers'
require_relative 'query_helpers'

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client

    @value_accessors = []
    @prepared_queries =
      @conf[:charts].map { |conf| prep_elastic_query(conf, @value_accessors) }
  end

  def query(filters)
    raw_results =
      @search_client.msearch(
        index: INDEX,
        body: @prepared_queries.map { |q| { search: q } }
      )

    LOGGER.info("Query took: #{raw_results['took']} ms")

    extracted_results = extract_results(raw_results, @value_accessors)
    formatted = format_results(extracted_results)

    { "selectedRecords": 6724, "totalRecords": 6724, "chartData": formatted }
  end

  def call(env)
    output = self.query([])

    [200, { 'content-type' => 'application/json' }, [output.to_json]]
  end
end
