require 'hocho/utils/finder'

module Hocho
  module InventoryProviders
    def self.find(name)
      Hocho::Utils::Finder.find(self, 'hocho/inventory_providers', name)
    end
  end
end
