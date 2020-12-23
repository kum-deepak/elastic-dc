require 'bundler/setup'
require 'elasticsearch'
require 'csv'
require 'active_support/core_ext/date'

ELASTIC_URL = 'http://localhost:9200'.freeze
INDEX = 'stocks'.freeze

def init_search_client(opts = {})
  opts = {
    url: ELASTIC_URL,
    adapter: :typhoeus,
    log: false
  }.merge(opts)

  Elasticsearch::Client.new(opts)
end
