# frozen_string_literal: true

# Elastic returns 10 buckets by default, to avoid that set a high enough size
MAX_BUCKETS = 10_000

def prep_elastic_query(dimension, groups, dims_and_groups)
  dim_conf = { terms: { field: dimension, size: MAX_BUCKETS, min_doc_count: 0 } }

  # sometimes more than one 'groups' can be associated with the same dimension
  groups = [groups].flatten

  queries =
    groups.map do |group|
      # the meta entries are returned by Elastic as part of the results.
      # These are used to arrange the output for specific charts
      query = {meta: { dimId: dimension, groupId: group }}

      query = query.merge(dim_conf)

      query[:aggs] = dims_and_groups[dimension][group] if dims_and_groups[dimension][group]

      query
    end

  # Make a Hash like {"0" => {...}, "1" => {...}}
  aggs = Hash[queries.each_with_index.map { |query, i| ["#{i}", query] }]

  # size: 0 instructs Elastic to not return any rows, it will ony return the aggregates
  { size: 0, aggs: aggs }
end

# filters from dc
#
# [{"chartId"=>"yearly-bubble-chart", "filterType"=>"Simple", "values"=>[1996]},
# {"chartId"=>"fluctuation-chart", "filterType"=>"RangedFilter", "values"=>[[-1, 5]]}]

# dc-to-elastic query predicate
def elastic_qry_predicate(filter)
  dimension = filter['dimId']
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
    else
      raise new Error("Unknown filter type: #{filter_type}")
    end

  [dimension, filter_clause]
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
  { query: { bool: { filter: applicable_clauses } } }
end
