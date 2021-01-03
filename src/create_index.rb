# frozen_string_literal: true
require_relative 'common'

# update it to suit your requirements. The index name in `conf.rb` must match.
INDEX = 'stocks'

search_client = init_search_client(log: true)

# Delete any existing indices, so that it does not interfere with existing data or schema
begin
  search_client.indices.delete(index: INDEX)
rescue Elasticsearch::Transport::Transport::Errors::NotFound => _e
  # Ignored - will error if index does not exist
end

# It is like an schema for the index.
# Though not required, it is advised that schema is declared with explicit field types.
#
# See: https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html
# https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-types.html
field_mappings = {
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

# https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-create-index.html
# https://rubydoc.info/gems/elasticsearch-api/Elasticsearch/API/Indices/Actions#create-instance_method
search_client.indices.create(
  index: INDEX,
  body: {
    settings: { index: { number_of_shards: 1, number_of_replicas: 0 } },
    mappings: field_mappings
  }
)
