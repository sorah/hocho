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
      host = inventory.filter({name: name}).first
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
    method_option :exclude, type: :string, default: '', aliases: %w(-e)
    method_option :driver, type: :string
    method_option :keep_synced_files, type: :boolean, default: false,
                  desc: "Keep the recipes on a server after run (for bundler and mitamae drivers)"
    def apply(name)
      hosts = inventory.filter({name: name}, exclude_filters: {name: options[:exclude]})
      if hosts.empty?
        raise "host name=#{name.inspect} not found"
      end

      if hosts.size > 1
        puts "Running sequencial on:"
        hosts.each do |host|
          puts " * #{host.name}"
        end
        puts
      end

      if config[:ask_sudo_password] || options[:sudo]
        print "sudo password: "
        sudo_password = $stdin.noecho { $stdin.gets.chomp }
        puts
      end

      hosts.each do |host|
        host.sudo_password = sudo_password if sudo_password
        Runner.new(
          host,
          driver: options[:driver],
          base_dir: config[:itamae_dir] || '.',
          initializers: config[:initializers] || [],
          driver_options: config[:driver_options] || {},
        ).run(
          dry_run: options[:dry_run],
          keep_synced_files: options[:keep_synced_files]
        )
      end
    rescue Hocho::Utils::Finder::NotFound => e
      abort e.message
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
