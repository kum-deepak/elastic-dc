# frozen_string_literal: true

require 'rack'
require 'json'

require_relative 'elastic_wrapper'

class ElasticWrapperRackApp < ElasticWrapper
  def call(env)
    request = Rack::Request.new(env)

    filters = request.params['filters']
    queries = request.params['queries']
    fetch_selected_count = request.params['selectedRecords']
    fetch_total_count = request.params['totalRecords']
    output = self.query(filters, queries, fetch_selected_count, fetch_total_count)

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
