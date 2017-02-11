require 'hocho/property_providers/base'

module Hocho
  module PropertyProviders
    class AddDefault < Base
      def initialize(properties: {})
        @properties = properties
      end

      def determine(host)
        host.properties.replace(host.properties.reverse_merge(@properties))
      end
    end
  end
end
