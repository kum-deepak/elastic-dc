# frozen_string_literal: true

require_relative 'result_helpers'
require_relative 'query_helpers'

class ElasticWrapper
  def initialize(conf, search_client)
    @conf = conf
    @search_client = search_client
  end

  def query(filters, queries, row_data_queries, fetch_selected_count, fetch_total_count)
    # We will make a single bulk queries to Elastic to fetch all required data
    #   First we will setup queries and their associated callback
    #     The callback will be invoked with the corresponding elastic result
    #     The callback is expected to add the result to ret_val

    ret_val = { 'chartData' => [], 'rowData' => [] }

    # This will have list of queries and associated callbacks
    elastic_queries_and_callbacks = []

    # Create Elastic query fragments for each filter
    filter_predicates = filters.map { |f| elastic_qry_predicate(f) }

    # count queries
    # To get count of selected records, all the filter applied
    if fetch_selected_count
      elastic_queries_and_callbacks.push(
        [selected_count_query(filter_predicates), ->(res) { ret_val['selectedRecords'] = extract_count(res) }],
      )
    end

    # To get count of all records
    if fetch_total_count
      elastic_queries_and_callbacks.push([total_count_query, ->(res) { ret_val['totalRecords'] = extract_count(res) }])
    end

    row_data_queries.each do |spec|
      elastic_queries_and_callbacks.push(
        [
          create_row_data_query(spec, filter_predicates),
          ->(res) do
            ret_val['rowData'].push({ specId: spec['specId'], res: extract_row_data_results(res, (spec['fields'])) })
          end,
        ],
      )
    end

    queries.each do |dimension, groups|
      # https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#a-group-does-not-observe-its-dimensions-filters
      applicable_clauses = filter_predicates.reject { |dim, _| dim == dimension }

      query =
        prep_elastic_query(dimension, groups, @conf['dims_and_groups']).merge(
          filters_to_elastic_query(applicable_clauses),
        )

      elastic_queries_and_callbacks.push([query, ->(res) { ret_val['chartData'].concat extract_chart_result(res) }])
    end

    # create separate lists
    elastic_queries, result_callbacks = elastic_queries_and_callbacks.transpose

    # https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions#msearch-instance_method
    qry_result = @search_client.msearch(index: @conf[:index], body: elastic_queries.map { |query| { search: query } })

    ret_val['elasticTime'] = qry_result['took']

    # pair each result with the corresponding callback, and invoke callbacks
    elastic_results_and_callbacks = qry_result['responses'].zip(result_callbacks)
    elastic_results_and_callbacks.each { |result, callback| callback.(result) }

    ret_val
  end
end
