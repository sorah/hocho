require 'thor'
require 'yaml'
require 'json'
require 'io/console'
require 'hocho/config'
require 'hocho/inventory'
require 'hocho/runner'

module Hocho
  class Command < Thor
    class_option :config, type: :string, desc: 'path to config file (default: ENV["HOCHO_CONFIG"] or ./hocho.yml)'

    desc "list", ""
    method_option :verbose, type: :boolean, default: false, alias: %w(-v)
    method_option :format, enum: %w(yaml json), default: 'yaml'
    def list
      hosts = inventory.hosts

      if options[:verbose]
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
    method_option :sudo,  type: :boolean, default: false
    method_option :dry_run, type: :boolean, default: false, aliases: %w(-n)
    method_option :driver, type: :string
    def apply(name)
      host = inventory.filter(name: name).first
      unless host
        raise "host name=#{name.inspect} not found"
      end

      if config[:ask_sudo_password] || options[:sudo]
        print "sudo password: "
        host.sudo_password = $stdin.noecho { $stdin.gets.chomp }
        puts
      end

      Runner.new(
        host,
        driver: options[:driver],
        base_dir: config[:itamae_dir] || '.',
        initializers: config[:initializers] || [],
        driver_options: config[:driver_options] || {},
      ).run(
        dry_run: options[:dry_run],
      )
    end

    private

    def inventory
      @inventory ||= Hocho::Inventory.new(config.inventory_providers, config.property_providers)
    end

    def config
      @config ||= Hocho::Config.load(config_file).tap do |c|
        Dir.chdir c.base_dir # XXX:
      end
    end

    def config_file
      options[:config] || ENV['HOCHO_CONFIG'] || './hocho.yml'
    end
  end
end
