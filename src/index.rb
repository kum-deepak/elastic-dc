require_relative 'lib/common'
require 'csv'
require 'active_support/core_ext/date'

search_client = init_search_client

# Delete any existing indices, so that it does not interfere with existing data or schema
search_client.indices.delete(index: '*')

search_client.indices.create(
  index: INDEX,
  body: { settings: { index: { number_of_shards: 1, number_of_replicas: 0 } } }
)

filed_mappings = {
  "dynamic": 'strict',
  "properties": {
    "id": { "type": 'integer' },
    "date": { "type": 'date' },
    "open": { "type": 'double' },
    "close": { "type": 'double' },
    "high": { "type": 'double' },
    "low": { "type": 'double' },
    "volume": { "type": 'integer' },
    "quarter": { "type": 'keyword' },
    "year": { "type": 'integer' },
    "month": { "type": 'date' },
    "gain_or_loss": { "type": 'keyword' },
    "fluctuation": { "type": 'integer' },
    "day_of_week": { "type": 'keyword' }
  }
}

search_client.indices.put_mapping(index: INDEX, body: filed_mappings)

rows = CSV.parse(File.open('data/ndx.csv'), headers: true)

processed_rows =
  rows.map do |row|
    # convert to simple Ruby Hash (from CSV specific Object)
    row = row.to_h

    row.delete('oi') # not required

    dt = Date.strptime(row['date'], '%m/%d/%Y')

    row['date'] = dt
    row['open'] = row['open'].to_f
    row['close'] = row['close'].to_f
    row['high'] = row['high'].to_f
    row['low'] = row['low'].to_f
    row['volume'] = row['volume'].to_i

    # pre compute for efficiency and ease
    row['quarter'] = "Q#{(dt.month + 2) / 3}" # .month returns 1..12 - we need Q1, Q2, Q3, Q4
    row['year'] = dt.year
    row['month'] = dt.at_beginning_of_month # to create a group on month
    row['gain_or_loss'] = row['open'] > row['close'] ? 'Loss' : 'Gain'
    row['fluctuation'] =
      (((row['close'] - row['open']) / row['open']) * 100).round
    row['day_of_week'] = dt.strftime('%w.%a') # '5.Fri'

    # search_client.index(id: i, index: 'stocks', body: row.to_h.to_json)
    row
  end

# id is optional, if not given Elastic generates it
body =
  processed_rows.each_with_index.map do |row, i|
    { 'index': { _id: i, data: row } }
  end

search_client.bulk(index: INDEX, body: body)
