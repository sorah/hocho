require 'hocho/utils/finder'

module Hocho
  module PropertyProviders
    def self.find(name)
      Hocho::Utils::Finder.find(self, 'hocho/property_providers', name)
    end
  end
end
