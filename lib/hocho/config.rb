require 'hocho/utils/symbolize'
require 'hocho/property_providers'
require 'hocho/inventory_providers'
require 'pathname'
require 'yaml'

module Hocho
  class Config
    DEFAULT_INVENTORY_PROVIDERS_CONFIG = [file: {path: './hosts.yml'}]

    def self.load(path)
      new YAML.load_file(path.to_s), base_dir: File.dirname(path.to_s)
    end

    def initialize(hash, base_dir: '.')
      @config = Hocho::Utils::Symbolize.keys_of(hash)
      @base_dir = Pathname(base_dir)
    end

    attr_reader :base_dir

    def [](k)
      @config[k]
    end

    def inventory_providers
      @inventory_providers ||= begin
        provider_specs = (@config[:inventory_providers] || DEFAULT_INVENTORY_PROVIDERS_CONFIG)
        if provider_specs.kind_of?(Hash)
          provider_specs = [provider_specs]
        end

        provider_specs.flat_map do |spec|
          raise TypeError, 'config inventory_providers[] should be an Hash' unless spec.kind_of?(Hash)
          spec.map do |name, options|
            InventoryProviders.find(name).new(**options)
          end
        end
      end
    end

    def property_providers
      @property_providers ||= begin
        provider_specs = (@config[:property_providers] || [])
        raise TypeError, 'config property_providers should be an Array' unless provider_specs.kind_of?(Array)
        provider_specs.flat_map do |spec|
          raise TypeError, 'config property_providers[] should be an Hash' unless spec.kind_of?(Hash)
          spec.map do |name, options|
            PropertyProviders.find(name).new(**options)
          end
        end
      end
    end

  end
end
