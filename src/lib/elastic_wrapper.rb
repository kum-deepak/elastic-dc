# frozen_string_literal: true

require_relative 'result_helpers'
require_relative 'query_helpers'

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client
  end

  def query(filters, queries, fetch_selected_count, fetch_total_count)
    filter_predicates = filters.map { |f| elastic_qry_predicate(f) }

    queries_with_filters =
      queries.map do |dimension, groups|
        query = prep_elastic_query(dimension, groups, @conf['dims_and_groups'])

        # https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#a-group-does-not-observe-its-dimensions-filters
        applicable_clauses = filter_predicates.reject { |dim, _| dim == dimension }

        query.merge(filters_to_elastic_query(applicable_clauses))
      end

    # To get count of selected records, all the filter applied
    queries_with_filters.push(selected_count_query(filter_predicates)) if fetch_selected_count
    # To get count of all records
    queries_with_filters.push(total_count_query) if fetch_total_count

    # https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions#msearch-instance_method
    qry_result =
      @search_client.msearch(index: @conf[:index], body: queries_with_filters.map { |query| { search: query } })

    elastic_time = qry_result['took']

    raw_results = qry_result['responses']

    all_count = extract_count(raw_results.pop) if fetch_total_count
    selected_count = extract_count(raw_results.pop) if fetch_selected_count

    chart_data = extract_results(raw_results)

    out = { elasticTime: elastic_time, chartData: chart_data }
    out['totalRecords'] = all_count if fetch_total_count
    out['selectedRecords'] = selected_count if fetch_selected_count

    out
  end
end
