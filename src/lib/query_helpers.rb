
def prep_elastic_query(entry, value_accessors)
  dim_conf = entry[:dimension]

  # sometimes more than one 'groups' can be associated with the same dimension
  charts = entry[:charts] ? entry[:charts] : [entry]

  agg_entries =
    charts.map do |chart_conf|
      # the meta entries are returned by Elastic as part of the results.
      # These are used to arrange the output for specific charts
      meta = chart_conf.slice(:chart_id, :layer, :name)

      if chart_conf[:value_accessor]
        # replace the lambda by the index where it is getting stored
        value_accessors.push(chart_conf[:value_accessor])
        meta[:value_accessor] = value_accessors.size - 1
      end

      # If there is a layer, ensure it has a name (as string)
      meta[:name] = "#{meta[:layer]}" if meta.key?(:layer) && !meta.key?(:name)
      aggs_entry = { meta: meta }

      aggs_entry = aggs_entry.merge(dim_conf)

      aggs_entry[:aggs] = chart_conf[:aggs] if chart_conf[:aggs]

      aggs_entry
    end

  # Make a Hash like {"0" => {...}, "1" => {...}}
  aggs =
    Hash[
      agg_entries.each_with_index.map { |aggs_entry, i| ["#{i}", aggs_entry] }
    ]

  # size: 0 instructs Elastic to not return any rows, it will ony return the aggregates
  { size: 0, aggs: aggs }
end
