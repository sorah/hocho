module Hocho
  module PropertyProviders
    class Base
      def determine(host)
        raise NotImplementedError
      end
    end
  end
end
