module Hocho
  module InventoryProviders
    class Base
      def hosts
        raise NotImplementedError
      end
    end
  end
end
