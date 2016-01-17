require 'tempfile'
require 'shellwords'
require 'json'

module Hocho
  module Drivers
    class Base
      def initialize(host, base_dir: '.', initializers: [])
        @host = host
        @base_dir = base_dir
        @initializers = initializers
      end

      attr_reader :host, :base_dir, :initializers

      def run(dry_run: false)
        raise NotImplementedError
      end

      def run_list
        [*initializers, *host.run_list]
      end

      private

      def node_json
        host.attributes.to_json
      end

      def with_node_json_file
        begin
          f = Tempfile.new('node-json')
          f.puts node_json
          f.flush
          yield f.path
        ensure
          f.close!
        end
      end
    end
  end
end
