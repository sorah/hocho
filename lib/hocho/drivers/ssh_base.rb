require 'hocho/drivers/base'
require 'securerandom'
require 'shellwords'

module Hocho
  module Drivers
    class SshBase < Base
      def ssh
        host.ssh_connection
      end

      private

      def prepare_sudo(password = host.sudo_password)
        raise "sudo password not present" if !host.nopasswd_sudo? && password.nil?

        if host.nopasswd_sudo?
          yield nil
          return
        end

        passphrase_env_name = "HOCHO_PA_#{SecureRandom.hex(8).upcase}"
        # password_env_name = "HOCHO_PB_#{SecureRandom.hex(8).upcase}"

        temporary_passphrase = SecureRandom.base64(128)

        encrypted_password = IO.pipe do |r,w|
          w.write temporary_passphrase
          w.close
          IO.popen([*%w(openssl enc -aes-128-cbc -pass fd:5 -a), 5 => r], "r+") do |io|
            io.puts password
            io.close_write
            io.read.chomp
          end
        end
        password[0,password.size] = ?\0 * password.size

        begin
          temp_executable = ssh.exec!('mktemp').chomp
          raise unless temp_executable.start_with?('/')

          ssh_run("chmod 0700 #{temp_executable.shellescape}; cat > #{temp_executable.shellescape}; chmod +x #{temp_executable.shellescape}") do |ch|
            ch.send_data("#!/bin/bash\nexec openssl enc -aes-128-cbc -d -a -pass env:#{passphrase_env_name} <<< #{encrypted_password.shellescape}\n")
            ch.eof!
          end

          sh = "#{passphrase_env_name}=#{temporary_passphrase.shellescape} SUDO_ASKPASS=#{temp_executable.shellescape} sudo -A "
          yield sh

        ensure
          ssh_run("shred --remove #{temp_executable.shellescape}")
        end
      end


      def host_tmpdir
        @host_tmpdir ||= begin
          mktemp_cmd = %w(mktemp -d -t hocho-run-XXXXXXXXX).shelljoin
          mktemp_cmd.prepend("TMPDIR=#{host.tmpdir.shellescape} ") if host.tmpdir

          res = ssh.exec!(mktemp_cmd)
          unless res.start_with?('/tmp')
            raise "Failed to mktemp #{mktemp_cmd.inspect} -> #{res.inspect}"
          end
          res.chomp
        end
      end

      def host_node_json_path
        "#{host_tmpdir}/node.json"
      end

      def with_host_node_json_file
        ssh_run("umask 0077 && cat > #{host_node_json_path.shellescape}") do |c|
          c.send_data "#{node_json}\n"
          c.eof!
        end

        yield host_node_json_path
      ensure
        ssh.exec!("rm #{host_node_json_path.shellescape}")
      end

      def ssh_run(cmd, error: true)
        exitstatus, exitsignal = nil

        puts "$ #{cmd}"
        cha = ssh.open_channel do |ch|
          ch.exec(cmd) do |c, success|
            raise "execution failed on #{host.name}: #{cmd.inspect}" if !success && error

            c.on_request("exit-status") { |c, data| exitstatus = data.read_long }
            c.on_request("exit-signal") { |c, data| exitsignal = data.read_long }

            yield c if block_given?
          end
        end
        cha.wait
        raise "execution failed on #{host.name} (status=#{exitstatus.inspect}, signal=#{exitsignal.inspect}): #{cmd.inspect}" if (exitstatus != 0 || exitsignal) && error
        [exitstatus, exitsignal]
      end
    end
  end
end
