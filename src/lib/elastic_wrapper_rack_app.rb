require 'rack'
require 'json'

require_relative 'elastic_wrapper'

class ElasticWrapperRackApp < ElasticWrapper
  def call(env)
    request = Rack::Request.new(env)

    filters = request.params['filters']
    output = self.query(filters)

    respond_json(output)
  end

  private

  def respond_json(output)
    response = Rack::Response.new
    response.set_header 'content-type', 'application/json'
    response.write output.to_json

    response.finish
  end
end
