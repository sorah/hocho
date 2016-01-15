require 'hashie'
require 'net/ssh'
require 'net/ssh/proxy/command'

module Hocho
  class Host
    def initialize(name, provider: nil, properties: {}, tags: {}, ssh_options: nil, tmpdir: nil, sudo_password: nil)
      @name = name
      @provider = provider
      self.properties = properties
      @tags = tags
      @override_ssh_options = ssh_options
      @tmpdir = tmpdir
      @sudo_password = sudo_password
    end

    attr_reader :name, :provider, :properties, :tmpdir
    attr_accessor :tags

    def to_h
      {
        name: name,
        provider: provider,
        tags: tags.to_h,
        properties: properties.to_h,
      }.tap do |h|
        h[:tmpdir] = tmpdir if tmpdir
        h[:ssh_options] = @override_ssh_options if @override_ssh_options
      end
    end

    def properties=(other)
      @properties = Hashie::Mash.new(other)
    end

    def add_properties_from_providers(providers)
      providers.each do |provider|
        provider.determine(self)
      end
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

    def nopasswd_sudo?
      !!properties[:nopasswd_sudo]
    end

    def ssh_options
      (Net::SSH::Config.for(name) || {}).merge(properties[:ssh_options] || {}).merge(@override_ssh_options || {})
    end

    def openssh_config
      ssh_options.flat_map do |key, value|
        case key
        when :encryption
          "Ciphers #{[*value].join(?,)}"
        when :compression
          "Compression #{value}"
        when :compression_level
          "CompressionLevel #{value}"
        when :timeout
          "ConnectTimeout #{value}"
        when :forward_agent
          "ForwardAgent #{value ? 'yes' : 'no'}"
        when :keys_only
          "IdentitiesOnly #{value ? 'yes' : 'no'}"
        when :global_known_hosts_file
          "GlobalKnownHostsFile #{value}"
        when :auth_methods
          [].tap do |lines|
            methods = []
            value.each  do |val|
              case val
              when 'hostbased'
                lines << "HostBasedAuthentication yes"
              when 'password'
                lines << "PasswordAuthentication yes"
              when 'publickey'
                lines << "PublickeyAuthentication yes"
              else
                methods << val
              end
            end
            unless methods.empty?
              lines << "PreferredAuthentications #{methods.join(?,)}"
            end
          end
        when :host_key
          "HostKeyAlgorithms #{[*value].join(?,)}"
        when :host_key_alias
          "HostKeyAlias #{value}"
        when :host_name
          "HostName #{value}"
        when :keys
          [*value].map do |val|
            "IdentityFile #{val}"
          end
        when :hmac
          "Macs #{[*value].join(?,)}"
        when :port
          "Port #{value}"
        when :proxy
          if value.kind_of?(Net::SSH::Proxy::Command)
            "ProxyCommand #{value.command_line_template}"
          else
            "ProxyCommand #{value}"
          end
        when :rekey_limit
          "RekeyLimit #{value}"
        when :user
          "User #{value}"
        when :user_known_hosts_file
          "UserKnownHostsFile #{value}"
        end
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
      Net::SSH.start(host.name, ENV['USER'], host.ssh_config)
    end
  end
end
