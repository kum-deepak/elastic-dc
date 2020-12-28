require_relative 'result_helpers'
require_relative 'query_helpers'

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client

    @value_accessors = []
    @prepared_queries =
      @conf[:charts].map do |chart_conf|
        prep_elastic_query(chart_conf, @value_accessors)
      end

    @value_accessors.deep_freeze
    @prepared_queries.deep_freeze
  end

  def query(filters)
    filter_predicates =
      associate_dimensions(filters, @prepared_queries)
        .map { |dimension, filter| elastic_qry_predicate(dimension, filter) }

    queries_with_filters =
      @prepared_queries.map do |dimension, query|
        # https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#a-group-does-not-observe-its-dimensions-filters
        applicable_clauses =
          adjust_filters_for_dimension(dimension, filter_predicates)

        query.merge(filter_to_elastic_query(applicable_clauses))
      end

    raw_results =
      @search_client.msearch(
        index: @conf[:index],
        body: queries_with_filters.map { |query| { search: query } }
      )

    extracted_results = extract_results(raw_results, @value_accessors)
    formatted = format_results(extracted_results)

    {
      elasticTime: raw_results['took'],
      "selectedRecords": 6724,
      "totalRecords": 6724,
      "chartData": formatted
    }
  end
end
