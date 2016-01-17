require 'hocho/utils/finder'

module Hocho
  module Drivers
    def self.find(name)
      Hocho::Utils::Finder.find(self, 'hocho/drivers', name)
    end
  end
end
