module Hocho
  class Inventory
    def initialize(providers, property_providers)
      @providers = providers
      @property_providers = property_providers
    end

    def hosts
      @hosts ||= @providers.inject({}) do |r,provider|
        provider.hosts.each do |host|
          if r.key?(host.name)
            r[host.name].merge!(host)
          else
            r[host.name] = host
          end
        end
        r
      end.each do |name, host|
        host.apply_property_providers(@property_providers)
      end.values
    end

    def filter(include_filters, exclude_filters: [])
      include_filters, exclude_filters = [include_filters, exclude_filters].map do |f|
        f.map do |name, value|
          values = value.to_s.split(?,).map! do |_|
            if _[0] == '/' && _[-1] == '/'
              Regexp.new(_[1...-1])
            else
              /#{Regexp.escape(_).gsub(/\*/,'.*')}/
            end
          end
          [name.to_s, values]
        end.to_h
      end

      filters = include_filters.map do |name, conditions|
        [name, [conditions, exclude_filters.fetch(name, [])]]
      end

      hosts.select do |host|
        filters.all? do |name, (conditions, exclude_conditions)|
          case name
          when 'name'
            conditions.any? { |c| host.name.match(c) } && !exclude_conditions.any? { |c| host.name.match(c) }
          else
            v = (host.attributes[name] || host.attributes[name.to_sym] || host.tags[name] || host.tags[name.to_sym])
            v && conditions.any? { |c| v.to_s.match(c) } && !exclude_conditions.any?{ |c| v.to_s.match(c) }
          end
        end
      end
    end
  end
end
