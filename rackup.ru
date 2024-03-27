require 'rack'
require 'rack/cors'
require 'rack/request'
require 'rack/response'
require 'rack/contrib/json_body_parser'

require_relative 'src/conf'
require_relative 'src/common'
require_relative 'src/lib/elastic_wrapper_rack_app'

search_client = init_search_client

app =
  Rack::Builder.app do
    # Enable CORS - needed for access through cross origin API access
    # The resource and methods may be setup be narrower
    use Rack::Cors do
      allow do
        origins '*'
        resource '*', headers: :any, methods: %i[get post patch put]
      end
    end

    map '/api/stock' do
      # The filters are passed as JSON body, this one parses the JSON body
      use Rack::JSONBodyParser

      run ElasticWrapperRackApp.new(CONF, search_client)
    end
  end

run app
