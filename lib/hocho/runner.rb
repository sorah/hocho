require 'hocho/drivers'

module Hocho
  class Runner
    def initialize(host, driver: nil, check_ssh_port: false, base_dir: '.', initializers: [], driver_options: {})
      @host = host
      @driver = driver && driver.to_sym
      @check_ssh_port = check_ssh_port
      @base_dir = base_dir
      @initializers = initializers
      @driver_options = driver_options

      @bundler_support = nil
    end

    attr_reader :host, :driver, :base_dir, :initializers

    def run(dry_run: false)
      puts "=> Running on #{host.name} using #{best_driver_name}"
      driver_options = @driver_options[best_driver_name] || {}
      driver = best_driver.new(host, base_dir: base_dir, initializers: initializers, **driver_options)
      driver.run(dry_run: dry_run)
    ensure
      driver.finalize if driver
    end

    # def check_ssh_port
    #   return unless @check_ssh_port
    # end

    def ssh
      host.ssh_connection
    end

    private

    def best_driver_name
      @best_driver_name ||= case
      when @driver
        @driver
      when @host.preferred_driver
        @host.preferred_driver
      when !bundler_support?
        :itamae_ssh
      else
        :bundler
      end
    end

    def best_driver
      @best_driver ||= Hocho::Drivers.find(best_driver_name)
    end

    def bundler_support?
      # ssh_askpass
      return @bundler_support unless @bundler_support.nil?
      @bundler_support = (ssh.exec!("#{host.bundler_cmd} -v") || '').match(/^Bundler version/)
    end
  end
end
