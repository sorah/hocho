require 'hocho/utils/symbolize'
require 'hashie'
require 'net/ssh'
require 'net/ssh/proxy/jump'
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
      @validated_ssh_options || normal_ssh_options
    end

    def candidate_ssh_options
      [
        normal_ssh_options,
        *alternate_ssh_options,
      ]
    end

    def normal_ssh_options
      (Net::SSH::Config.for(ssh_name) || {}).merge(Hocho::Utils::Symbolize.keys_of(properties[:ssh_options] || {})).merge(@override_ssh_options || {})
    end

    def alternate_ssh_options
      alts = properties.fetch(:alternate_ssh_options, nil)
      list = case alts
      when Hash
        [alts]
      when Array
        alts
      when nil
        []
      else
        raise TypeError, "alternate_ssh_options should be a Hash or Array"
      end
      list.map do |opts|
        normal_ssh_options.merge(Hocho::Utils::Symbolize.keys_of(opts))
      end
    end

    def openssh_config(separator='=')
      ssh_options.flat_map do |key, value|
        case key
        when :encryption
         [["Ciphers", [*value].join(?,)]]
        when :compression
         [["Compression", value ? 'yes' : 'no']]
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
          when Net::SSH::Proxy::Jump
            [["ProxyJump", value.jump_proxies]]
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
        when :verify_host_key
          case value
          when :never
            [["StrictHostKeyChecking", "no"]]
          when :accept_new_or_local_tunnel
            [["StrictHostKeyChecking", "accept-new"]]
          when :accept_new
            [["StrictHostKeyChecking", "accept-new"]]
          when :always
            [["StrictHostKeyChecking", "yes"]]
          end
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
      ssh_options_candidates = candidate_ssh_options()
      ssh_options_candidates_size = ssh_options_candidates.size
      tries = 1
      begin
        # A workaround for a bug on net-ssh: https://github.com/net-ssh/net-ssh/issues/764
        # :strict_host_key_checking is translated from ssh config. However, Net::SSH.start does not accept
        # the option as valid one. Remove this part when net-ssh fixes the bug.
        options = ssh_options_candidates[0]
        unless Net::SSH::VALID_OPTIONS.include?(:strict_host_key_checking)
          options.delete(:strict_host_key_checking)
        end
        retval = Net::SSH.start(name, nil, options)
        @validated_ssh_options = options
        retval
      rescue Net::SSH::Exception, Errno::ECONNREFUSED, Net::SSH::Proxy::ConnectError => e
        raise unless ssh_options_candidates.shift
        tries += 1
        puts "[#{name}] Trying alternate ssh options due to #{e.inspect} (#{tries}/#{ssh_options_candidates_size})"
        retry
      end
    end

    def compress?
      properties.fetch(:compress, true)
    end
  end
end
