require 'thor'
require 'yaml'
require 'json'
require 'hocho/config'
require 'hocho/inventory'
# require 'hocho/runner'

module Hocho
  class Command < Thor
    class_option :config, type: :string, desc: 'path to config file (default: ENV["HOCHO_CONFIG"] or ./hocho.yml)'

    desc "list", ""
    method_option :verbose, type: :boolean, default: false, alias: %w(-v)
    method_option :format, enum: %w(yaml json), default: 'yaml'
    def list
      hosts = inventory.hosts

      if options[:verbose]
        hosts.each do |host|
          config.property_providers.each { |_| _.determine(host) }
        end
        case options[:format]
        when 'yaml'
          puts hosts.map(&:to_h).to_yaml
        when 'json'
          puts hosts.map(&:to_h).to_json
        end
      else
        case options[:format]
        when 'yaml'
          puts hosts.map(&:name).to_yaml
        when 'json'
          puts hosts.map(&:name).to_json
        end
      end
    end

    desc "show NAME", ""
    method_option :format, enum: %w(yaml json), default: 'yaml'
    def show(name)
      host = inventory.filter(name: name).first
      if host
        case options[:format]
        when 'yaml'
          puts host.to_h.to_yaml
        when 'json'
          puts host.to_h.to_json
        end
      else
        raise "host name=#{name.inspect} not found"
      end
    end

    desc "apply HOST", "run itamae"
    method_option :dry_run, type: :boolean, default: false, alias: %w(-n)
    method_option :driver, type: :string
    def apply(name)
      # host = inventory.filter(name: name).first
      # unless host
      #   raise "host name=#{name.inspect} not found"
      # end


    end

    private

    def inventory
      @inventory ||= Hocho::Inventory.new(config.inventory_providers)
    end

    def config
      @config ||= Hocho::Config.load(config_file)
    end

    def config_file
      options[:config] || ENV['HOCHO_CONFIG'] || './hocho.yml'
    end
  end
end
