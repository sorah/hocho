module Hocho
  module Utils
    module Symbolize
      def self.keys_of(obj)
        case obj
        when Hash
          Hash[obj.map { |k, v| [k.is_a?(String) ? k.to_sym : k, keys_of(v)] }]
        when Array
          obj.map { |v| keys_of(v) }
        else
          obj
        end
      end
    end
  end
end
