require 'rack'
require 'json'

require_relative 'result_helpers'
require_relative 'query_helpers'

# [{"chartId"=>"yearly-bubble-chart", "filterType"=>"Simple", "values"=>[1996]},
# {"chartId"=>"fluctuation-chart", "filterType"=>"RangedFilter", "values"=>[[-1, 5]]}]

def generate_filter(dimension, filter)
  filter_type = filter['filterType']
  values = filter['values']

  filter_clause =
    case filter_type
    when 'Simple'
      { terms: { dimension => values } }
    when 'RangedFilter'
      low, high = values[0]
      { range: { dimension => { gte: low, lt: high } } }
    end

  [dimension, filter_clause]
end

def prep_filters(filters, prepared_queries)
  filters.map do |filter|
    dimension, _ =
      prepared_queries.find do |_, q|
        (q[:aggs].values.map { |e| e[:meta][:chart_id] }).include?(
          filter['chartId']
        )
      end

    generate_filter(dimension, filter)
  end
end

def filter_to_query(filters_info, dimension = nil)
  applicable_clauses =
    filters_info.reject { |dim, _| dim == dimension }.map { |dim, f| f }

  { "query": { "bool": { "filter": applicable_clauses } } }
end

# { size: 0, query: {bool: { filter: [{ terms: { year: [1999, 2000] }}, {terms: { quarter: ['Q4']}}] }} }

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client

    @value_accessors = []
    @prepared_queries =
      @conf[:charts].map { |conf| prep_elastic_query(conf, @value_accessors) }

    @value_accessors.deep_freeze
    @prepared_queries.deep_freeze
  end

  def query(filters)
    LOGGER.info(filters)
    filter_predicates = prep_filters(filters, @prepared_queries)
    LOGGER.info(filter_predicates)

    raw_results =
      @search_client.msearch(
        index: INDEX, # TODO: move INDEX to conf
        body:
          @prepared_queries.map do |dimension, q|
            query = q.merge(filter_to_query(filter_predicates, dimension))

            { search: query }
          end
      )

    LOGGER.info("Query took: #{raw_results['took']} ms")

    extracted_results = extract_results(raw_results, @value_accessors)
    formatted = format_results(extracted_results)

    { "selectedRecords": 6724, "totalRecords": 6724, "chartData": formatted }
  end

  def call(env)
    request = Rack::Request.new(env)

    filters = request.params['filters']
    output = self.query(filters)

    respond_json(output)
  end

  private

  def respond_json(output)
    response = Rack::Response.new
    response.set_header 'content-type', 'application/json'
    response.write output.to_json

    response.finish
  end
end
