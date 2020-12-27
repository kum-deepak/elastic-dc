require 'rack'
require 'rack/cors'
require 'rack/request'
require 'rack/response'
require 'rack/contrib/json_body_parser'

require_relative 'src/conf'
require_relative 'src/common'
require_relative 'src/lib/elastic_wrapper'

search_client = init_search_client

app = Rack::Builder.app do
  use Rack::CommonLogger
  use Rack::Cors do
    allow do
      origins '*'
      resource '*', headers: :any, methods: [:get, :post, :patch, :put]
    end
  end
  use Rack::JSONBodyParser

  run ElasticWrapper.new(CONF, search_client)
end

run app


