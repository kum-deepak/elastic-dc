# frozen_string_literal: true

require_relative 'result_helpers'
require_relative 'query_helpers'

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client
  end

  def query(filters, queries)
    filter_predicates = filters.map { |f| elastic_qry_predicate(f) }

    queries_with_filters =
      queries.map do |dimension, groups|
        query = prep_elastic_query(dimension, groups, @conf['dims_and_groups'])

        # https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#a-group-does-not-observe-its-dimensions-filters
        applicable_clauses = filter_predicates.reject { |dim, _| dim == dimension }

        query.merge(filters_to_elastic_query(applicable_clauses))
      end

    add_queries_for_counts(filter_predicates, queries_with_filters)

    # https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions#msearch-instance_method
    qry_result =
      @search_client.msearch(index: @conf[:index], body: queries_with_filters.map { |query| { search: query } })

    elastic_time = qry_result['took']

    raw_results = qry_result['responses']

    all_count, selected_count = extract_counts(filter_predicates, raw_results)

    chart_data = extract_results(raw_results)

    { elasticTime: elastic_time, selectedRecords: selected_count, totalRecords: all_count, chartData: chart_data }
  end

  private

  def add_queries_for_counts(filter_predicates, queries_with_filters)
    # To get count of selected records, all the filter applied
    # not needed if there are no filters
    unless filter_predicates.empty?
      queries_with_filters.push({ size: 0 }.merge(filters_to_elastic_query(filter_predicates)))
    end

    # To get count of all records
    queries_with_filters.push({ size: 0 })
  end

  def extract_counts(filter_predicates, raw_results)
    res_all = raw_results.pop
    all_count = res_all['hits']['total']['value']

    selected_count =
      if filter_predicates.empty?
        all_count
      else
        res_selected = raw_results.pop
        res_selected['hits']['total']['value']
      end

    [all_count, selected_count]
  end
end
