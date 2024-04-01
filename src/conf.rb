# frozen_string_literal: true
require 'deep-freeze'

# DIMENSIONS & GROUPS

# A dimension will get aggregated based on unique values. In final output
# `key` will be value of the dimension. By default number of matched documents
# will be the `value`.
#
# You can specify special aggregations using Elastic Aggregation syntax.
# https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations.html
#
# It is likely that dimensions will be based on term
# https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html

# These will get converted to term aggregations like
# { terms: { field: 'year', size: 10000 } }
#
# Each Dimension must be a field as per index definition.

# CUSTOM AGGREGATIONS (similar to Crossfilter custom Groups)

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

# moveMonths.group().reduceSum(d => Math.abs(d.close - d.open))
index_move_by_month = {
  only_me: {
    sum: {
      "script": { "source": 'Math.abs( doc.close.value - doc.open.value )' }
    }
  }
}

# moveMonths.group().reduceSum(d => d.volume / 500000);
# Since volume is integer as per index definition, it is important to use 500000.0 to avoid integer division
volume_by_month_group_agg = {
  only_me: { sum: { "script": { "source": 'doc.volume.value / 500000.0' } } }
}

# ++p.days;
# p.total += (v.open + v.close) / 2;
# p.avg = Math.round(p.total / p.days);
#
# Elastic has concept of pipeline aggregations
# (https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-pipeline.html)
# These help in computing derived values based on other aggregations.
# For example, in this case after computing average, it is rounded
index_avg_by_month_agg = {
  avg_without_rounding: {
    avg: { "script": { "source": '( doc.open.value + doc.close.value ) / 2' } }
  },
  avg: {
    bucket_script: {
      buckets_path: { avg_without_rounding: 'avg_without_rounding' },
      script: 'Math.round(params.avg_without_rounding)'
    }
  }
}

# creating aggregation for these (from stock.js example)
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

# Only the CONF is used outside this file

CONF = {
  # whether to include selected/total row-counts
  counts: true,
  index: 'stocks',
  charts: [
    {
      dimension: 'year',
      chart_id: 'yearly-bubble-chart',
      aggs: yearly_bubble_chart_agg,
    },
    { chart_id: 'gain-loss-chart', dimension: 'gain_or_loss' },
    { chart_id: 'day-of-week-chart', dimension: 'day_of_week' },
    {
      chart_id: 'quarter-chart',
      dimension: 'quarter',
      aggs: quarter_chart_agg
    },
    # For stack based charts `layer` must be set.
    # If there are more than one layer, these will have values 0, 1, 2, ...
    { chart_id: 'fluctuation-chart', dimension: 'fluctuation', layer: 0 },
    # It is possible to link more than one chart to the same dimension.
    # In this case, two layers of 'monthly-move-chart' and one layer of 'monthly-volume-chart'
    # are attached to the same dimension.
    #
    # `name` must be set in case there are more than one layer for a chart.
    {
      dimension: 'month',
      charts: [
        {
          chart_id: 'monthly-move-chart',
          aggs: index_avg_by_month_agg,
          name: 'Monthly Index Average',
          layer: 0
        },
        {
          chart_id: 'monthly-move-chart',
          aggs: index_move_by_month,
          name: 'Monthly Index Move',
          layer: 1
        },
        {
          chart_id: 'monthly-volume-chart',
          aggs: volume_by_month_group_agg,
          layer: 0
        }
      ]
    }
  ]
}.deep_freeze # make this Object immutable
