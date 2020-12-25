
yearly_dimension = { terms: { field: 'year', size: 1000 } }.freeze

CONF = [
  {
    chart_id: 'yearly-bubble-chart',
    dimension: yearly_dimension,
    # p.absGain += v.close - v.open;
    # p.fluctuation += Math.abs(v.close - v.open);
    # p.sumIndex += (v.open + v.close) / 2;
    # p.avgIndex = p.sumIndex / p.count;
    # p.percentageGain = p.avgIndex ? (p.absGain / p.avgIndex) * 100 : 0;
    # p.fluctuationPercentage = p.avgIndex ? (p.fluctuation / p.avgIndex) * 100 : 0;
    aggs: {
      avgIndex: {
        avg: {
          "script": { "source": '( doc.open.value + doc.close.value ) / 2' }
        }
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
  }
].freeze
