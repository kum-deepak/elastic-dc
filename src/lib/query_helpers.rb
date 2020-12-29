# Elastic returns 10 buckets by default, to avoid that set a high enough size
MAX_BUCKETS = 10_000

def prep_elastic_query(entry, value_accessors)
  dimension = entry[:dimension]
  dim_conf = { terms: { field: dimension, size: MAX_BUCKETS, min_doc_count: 0 } }

  # sometimes more than one 'groups' can be associated with the same dimension
  charts = entry[:charts] ? entry[:charts] : [entry]

  agg_entries =
    charts.map do |chart_conf|
      # the meta entries are returned by Elastic as part of the results.
      # These are used to arrange the output for specific charts
      meta = chart_conf.slice(:chart_id, :layer, :name)

      if chart_conf[:value_accessor]
        # replace the lambda by the index where it is getting stored
        value_accessors.push(chart_conf[:value_accessor])
        meta[:value_accessor] = value_accessors.size - 1
      end

      # If there is a layer, ensure it has a name (as string)
      meta[:name] = "#{meta[:layer]}" if meta.key?(:layer) && !meta.key?(:name)
      aggs_entry = { meta: meta }

      aggs_entry = aggs_entry.merge(dim_conf)

      aggs_entry[:aggs] = chart_conf[:aggs] if chart_conf[:aggs]

      aggs_entry
    end

  # Make a Hash like {"0" => {...}, "1" => {...}}
  aggs =
    Hash[
      agg_entries.each_with_index.map { |aggs_entry, i| ["#{i}", aggs_entry] }
    ]

  # size: 0 instructs Elastic to not return any rows, it will ony return the aggregates
  [dimension, { size: 0, aggs: aggs }]
end

# filters from dc
#
# [{"chartId"=>"yearly-bubble-chart", "filterType"=>"Simple", "values"=>[1996]},
# {"chartId"=>"fluctuation-chart", "filterType"=>"RangedFilter", "values"=>[[-1, 5]]}]

# dc-to-elastic query predicate
def elastic_qry_predicate(dimension, filter)
  filter_type = filter['filterType']
  values = filter['values']

  filter_clause =
    case filter_type
    when 'Simple'
      { terms: { dimension => values } }
    when 'RangedFilter'
      low, high = values[0]

      # https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#filterrange-does-not-include-the-top-point
      { range: { dimension => { gte: low, lt: high } } }
    end

  [dimension, filter_clause]
end

# From chart_ids, find dimensions
def associate_dimensions(filters, prepared_queries)
  filters.map do |filter|
    dimension, _ =
      prepared_queries.find do |_, q|
        (q[:aggs].values.map { |e| e[:meta][:chart_id] }).include?(
          filter['chartId']
        )
      end

    [dimension, filter]
  end
end

# https://github.com/crossfilter/crossfilter/wiki/Crossfilter-Gotchas#a-group-does-not-observe-its-dimensions-filters
# This method emulates the behavior
def adjust_filters_for_dimension(dimension, filters_info)
  filters_info.reject { |dim, _| dim == dimension }
end

# Query fragment to Elastic
#
# {
#   query: {
#     bool: {
#       filter: [
#         { terms: { year: [1999, 2000] } },
#         { terms: { quarter: ['Q4'] } },
#         {
#           range: {
#             'month' => {
#               gte: '1992-03-24T19:55:24.342Z',
#               lt: '2006-11-18T20:59:16.312Z'
#             }
#           }
#         }
#       ]
#     }
#   }
# }
def filters_to_elastic_query(applicable_clauses)
  applicable_clauses = applicable_clauses.map { |_, f| f }
  { "query": { "bool": { "filter": applicable_clauses } } }
end
