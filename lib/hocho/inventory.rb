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

    def filter(filters)
      filters = filters.map do |name, value|
        [name.to_s, value.to_s.split(?,).map! { |_| /#{Regexp.escape(_).gsub(/\\*/,'.*')}/ }]
      end.to_h

      hosts.select do |host|
        filters.all? do |name, conditions|
          case name
          when 'name'
            conditions.any? { |c| host.name.match(c) }
          else
            v = (host.attributes[name] || host.attributes[name.to_sym] || host.tags[name] || host.tags[name.to_sym])
            v && conditions.any? { |c| v.to_s.match(c) }
          end
        end
      end
    end
  end
end
