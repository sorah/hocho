module Hocho
  module PropertyProviders
    class RubyScript
      def initialize(name: nil, script: nil, file: nil)
        @template = case
        when script
          compile(script, "(#{name || 'ruby_script'})")
        when file
          compile(File.read(file), name ? "(#{name})" : file)
        end
      end

      def determine(host)
        @template.new(host).run
        nil
      end

      private

      Template = Struct.new(:host)

      def compile(script, name)
        binding.eval("Class.new(Template) { def run;\n#{script}\nend; }", name, 0)
      end
    end
  end
end
