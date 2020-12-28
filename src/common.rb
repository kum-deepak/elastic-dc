require 'bundler/setup'
require 'elasticsearch'
require 'active_support/core_ext/hash'
require 'logger'

LOGGER = Logger.new(STDERR)

ELASTIC_URL = 'http://localhost:9200'.freeze

def init_search_client(opts = {})
  opts = { url: ELASTIC_URL, adapter: :typhoeus, log: false }.merge(opts)

  Elasticsearch::Client.new(opts)
end
