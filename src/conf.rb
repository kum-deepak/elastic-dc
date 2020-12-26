# Elastic returns 10 buckets by default, to avoid that set a high enough size
BKTS = 10_000

# A dimension will get aggregated based on unique values. In final output
# `key` will be value of the dimension. By default number of matched documents
# will be the `value`.
#
# You can specify special aggregations using Elastic Aggregation syntax.
# https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
#
# It is likely that dimensions will be based on term
# https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html

yearly_dimension = { terms: { field: 'year', size: BKTS } }.freeze
gain_or_loss_dimension = { terms: { field: 'gain_or_loss', size: BKTS } }.freeze
quarter_dimension = { terms: { field: 'quarter', size: BKTS } }.freeze
fluctuation_dimension = { terms: { field: 'fluctuation', size: BKTS } }.freeze
day_of_week_dimension = { terms: { field: 'day_of_week', size: BKTS } }.freeze
month_dimension = { terms: { field: 'month', size: BKTS } }.freeze

# creating agg for these (from stock.js example)
# p.absGain += v.close - v.open;
# p.fluctuation += Math.abs(v.close - v.open);
# p.sumIndex += (v.open + v.close) / 2;
# p.avgIndex = p.sumIndex / p.count;
# p.percentageGain = p.avgIndex ? (p.absGain / p.avgIndex) * 100 : 0;
# p.fluctuationPercentage = p.avgIndex ? (p.fluctuation / p.avgIndex) * 100 : 0;
yearly_bubble_chart_agg = {
  avgIndex: {
    avg: { "script": { "source": '( doc.open.value + doc.close.value ) / 2' } }
  },
  absGain: {
    sum: { "script": { "source": '( doc.close.value - doc.open.value )' } }
  },
  fluctuation: {
    sum: {
      "script": { "source": 'Math.abs( doc.close.value - doc.open.value )' }
    }
  },
  percentageGain: {
    bucket_script: {
      buckets_path: { avgIndex: 'avgIndex', absGain: 'absGain' },
      script: 'params.absGain / params.avgIndex * 100'
    }
  },
  fluctuationPercentage: {
    bucket_script: {
      buckets_path: { avgIndex: 'avgIndex', fluctuation: 'fluctuation' },
      script: 'params.fluctuation / params.avgIndex * 100'
    }
  }
}

# The custom aggregations will return an Object
#       {
#         "key": "Q1",
#         "value": {
#           "doc_count": 1668,
#           "volume": 18819625217.0
#         }
#       }
# To only get the value like the following, use `only_me` as the aggregation name
#       {
#         "key": "Q1",
#         "value": 18819625217.0
#       }
# Equivalent to the following from stock.js
# quarter.group().reduceSum(d => d.volume)
quarter_chart_agg = { only_me: { sum: { field: 'volume' } } }

# moveMonths.group().reduceSum(d => d.volume / 500000);
# Since volume is integer as per index definition, it is important to use 500000.0 to avoid integer division
volume_by_month_group_agg = {
  only_me: { sum: { "script": { "source": 'doc.volume.value / 500000.0' } } }
}

CONF = [
  {
    dimension: yearly_dimension,
    chart_id: 'yearly-bubble-chart',
    aggs: yearly_bubble_chart_agg
  },
  { chart_id: 'gain-loss-chart', dimension: gain_or_loss_dimension },
  { chart_id: 'day-of-week-chart', dimension: day_of_week_dimension },
  {
    chart_id: 'quarter-chart',
    dimension: quarter_dimension,
    aggs: quarter_chart_agg
  },
  { chart_id: 'fluctuation-chart', dimension: fluctuation_dimension },
  {
    chart_id: 'monthly-volume-chart',
    dimension: month_dimension,
    aggs: volume_by_month_group_agg
  }
].freeze
