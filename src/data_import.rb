# frozen_string_literal: true
require_relative 'common'
require 'csv'
require 'active_support/core_ext/date'

INDEX = 'stocks'.freeze
search_client = init_search_client

rows = CSV.parse(File.open('data/ndx.csv'), headers: true)

processed_rows =
  rows.map do |row|
    # convert to simple Ruby Hash (from CSV specific Object)
    # Needed for JSON serialization to work properly.
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

    row
  end

# id is optional, if not given Elastic generates it
body =
  processed_rows.each_with_index.map do |row, i|
    { 'index': { _id: i, data: row } }
  end

# https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Actions#bulk-instance_method
# https://www.elastic.co/guide/en/elasticsearch/reference/7.10/docs-bulk.html
search_client.bulk(index: INDEX, body: body)
