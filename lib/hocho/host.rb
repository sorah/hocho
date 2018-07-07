require 'hocho/utils/symbolize'
require 'hashie'
require 'net/ssh'
require 'net/ssh/proxy/command'

module Hocho
  class Host
    def initialize(name, provider: nil, providers: nil, properties: {}, tags: {}, ssh_options: nil, tmpdir: nil, shmdir: nil, sudo_password: nil)
      if provider
        warn "DEPRECATION WARNING: #{caller[1]}: Hocho::Host.new(provider:) is deprecated. Use providers: instead "
      end

      @name = name
      @providers = [*provider, *providers]
      self.properties = properties
      @tags = tags
      @override_ssh_options = ssh_options
      @tmpdir = tmpdir
      @shmdir = shmdir
      @sudo_password = sudo_password
    end

    attr_reader :name, :providers, :properties, :tmpdir, :shmdir
    attr_writer :sudo_password
    attr_accessor :tags

    def to_h
      {
        name: name,
        providers: providers,
        tags: tags.to_h,
        properties: properties.to_h,
      }.tap do |h|
        h[:tmpdir] = tmpdir if tmpdir
        h[:shmdir] = shmdir if shmdir
        h[:ssh_options] = @override_ssh_options if @override_ssh_options
      end
    end

    def properties=(other)
      @properties = Hashie::Mash.new(other)
    end

    def merge!(other)
      @tags.merge!(other.tags) if other.tags
      @tmpdir = other.tmpdir if other.tmpdir
      @shmdir = other.shmdir if other.shmdir
      @properties.merge!(other.properties)
    end

    def apply_property_providers(providers)
      providers.each do |provider|
        provider.determine(self)
      end
    end

    def ssh_name
      properties[:ssh_name] || name
    end

    def run_list
      properties[:run_list] || []
    end

    def attributes
      properties[:attributes] || {}
    end

    def sudo_password
      @sudo_password || properties[:sudo_password] || ENV['SUDO_PASSWORD']
    end

    def sudo_required?
      properties.fetch(:sudo_required, true)
    end

    def nopasswd_sudo?
      !!properties[:nopasswd_sudo]
    end

    def ssh_options
      (Net::SSH::Config.for(ssh_name) || {}).merge(Hocho::Utils::Symbolize.keys_of(properties[:ssh_options] || {})).merge(@override_ssh_options || {})
    end

    def openssh_config(separator='=')
      ssh_options.flat_map do |key, value|
        case key
        when :encryption
         [["Ciphers", [*value].join(?,)]]
        when :compression
         [["Compression", value]]
        when :compression_level
         [["CompressionLevel", value]]
        when :timeout
         [["ConnectTimeout", value]]
        when :forward_agent
         [["ForwardAgent", value ? 'yes' : 'no']]
        when :keys_only
         [["IdentitiesOnly", value ? 'yes' : 'no']]
        when :global_known_hosts_file
         [["GlobalKnownHostsFile", value]]
        when :auth_methods
          [].tap do |lines|
            methods = value.dup
            value.each  do |val|
              case val
              when 'hostbased'
                lines << ["HostBasedAuthentication", "yes"]
              when 'password'
                lines << ["PasswordAuthentication", "yes"]
              when 'publickey'
                lines << ["PubkeyAuthentication", "yes"]
              end
            end
            unless methods.empty?
              lines << ["PreferredAuthentications", methods.join(?,)]
            end
          end
        when :host_key
         [["HostKeyAlgorithms", [*value].join(?,)]]
        when :host_key_alias
         [["HostKeyAlias", value]]
        when :host_name
         [["HostName", value]]
        when :keys
          [*value].map do |val|
           ["IdentityFile", val]
          end
        when :hmac
         [["Macs", [*value].join(?,)]]
        when :port
         [["Port", value]]
        when :proxy
          case value
          when Net::SSH::Proxy::Command
           [["ProxyCommand", value.command_line_template]]
          when false
           [["ProxyCommand", 'none']]
          else
           [["ProxyCommand", value]]
          end
        when :rekey_limit
         [["RekeyLimit", value]]
        when :user
         [["User", value]]
        when :user_known_hosts_file
         [["UserKnownHostsFile", value]]
        end
      end.compact.map do |keyval|
        keyval.join(separator)
      end
    end

    def hostname
      ssh_options[:host_name] || name
    end

    def user
      ssh_options[:user]
    end

    def ssh_port
      ssh_options[:port]
    end

    def preferred_driver
      properties[:preferred_driver] && properties[:preferred_driver].to_sym
    end

    def bundler_cmd
      properties[:bundler_cmd] || 'bundle'
    end

    def ssh_connection
      @ssh ||= make_ssh_connection
    end

    def make_ssh_connection
      Net::SSH.start(name, nil, ssh_options)
    end
  end
end
