require 'hocho/drivers/base'
require 'securerandom'
require 'shellwords'

module Hocho
  module Drivers
    class SshBase < Base
      def ssh
        host.ssh_connection
      end

      def finalize
        return if @keep_synced_files

        remove_host_tmpdir!
        remove_host_shmdir!
      end

      # @param deploy_dir [String] path on the server to copy the files to. If not specified, an automatic dir in /tmp is used
      # @param shm_prefix [Array<String>] additional directories that will be copied to /dev/shm on the server
      def deploy(deploy_dir: nil, shm_prefix: [])
        @host_basedir = deploy_dir if deploy_dir

        shm_prefix = [*shm_prefix]

        ssh_cmd = ['ssh', *host.openssh_config.flat_map { |l| ['-o', "\"#{l}\""] }].join(' ')
        shm_exclude = shm_prefix.map{ |_| "--exclude=#{_}" }
        compress = host.compress? ? ['-z'] : []
        hostname = host.hostname.include?(?:) ? "[#{host.hostname}]" : host.hostname # surround with square bracket for ipv6 address
        rsync_cmd = [*%w(rsync -a --copy-links --copy-unsafe-links --delete --exclude=.git), *compress, *shm_exclude, '--rsh', ssh_cmd, '.', "#{hostname}:#{host_basedir}"]

        puts "=> $ #{rsync_cmd.shelljoin}"
        system(*rsync_cmd, chdir: base_dir) or raise 'failed to rsync'

        unless shm_prefix.empty?
          shm_include = shm_prefix.map{ |_| "--include=#{_.sub(%r{/\z},'')}/***" }
          rsync_cmd = [*%w(rsync -a --copy-links --copy-unsafe-links --delete), *compress, *shm_include, '--exclude=*', '--rsh', ssh_cmd, '.', "#{hostname}:#{host_shm_basedir}"]
          puts "=> $ #{rsync_cmd.shelljoin}"
          system(*rsync_cmd, chdir: base_dir) or raise 'failed to rsync'
          shm_prefix.each do |x|
            mkdir = if %r{\A[^/].*\/.+\z} === x
                      %Q(mkdir -vp "$(basename #{x.shellescape})" &&)
                    else
                      nil
                    end
            ssh_run(%Q(cd #{host_basedir} && #{mkdir} ln -sfv #{host_shm_basedir}/#{x.shellescape} ./#{x.sub(%r{/\z},'').shellescape}))
          end
        end

        yield
      end

      private

      def prepare_sudo(password = host.sudo_password)
        raise "sudo password not present" if host.sudo_required? && !host.nopasswd_sudo? && password.nil?

        unless host.sudo_required?
          yield nil, nil, ""
          return
        end

        if host.nopasswd_sudo?
          yield nil, nil, "sudo "
          return
        end

        passphrase_env_name = "HOCHO_PA_#{SecureRandom.hex(8).upcase}"
        # password_env_name = "HOCHO_PB_#{SecureRandom.hex(8).upcase}"

        temporary_passphrase = SecureRandom.base64(129).chomp

        local_supports_pbkdf2 = system(*%w(openssl enc -pbkdf2), in: File::NULL, out: File::NULL, err: [:child, :out])
        remote_supports_pbkdf2 = begin
                                   exitstatus, * = ssh_run("openssl enc -pbkdf2", error: false, &:eof!)
                                   exitstatus == 0
                                 end
        derive = local_supports_pbkdf2 && remote_supports_pbkdf2 ? %w(-pbkdf2) : []

        encrypted_password = IO.pipe do |r,w|
          w.write temporary_passphrase
          w.close
          IO.popen([*%w(openssl enc -aes-128-cbc -pass fd:5 -a -md sha256), *derive, 5 => r], "r+") do |io|
            io.puts password
            io.close_write
            io.read.chomp
          end
        end

        begin
          tmpdir = host_shmdir ? "TMPDIR=#{host_shmdir.shellescape} " : nil
          temp_executable = ssh.exec!("#{tmpdir}mktemp").chomp
          raise unless temp_executable.start_with?('/')

          ssh_run("chmod 0700 #{temp_executable.shellescape}; cat > #{temp_executable.shellescape}; chmod +x #{temp_executable.shellescape}") do |ch|
            ch.send_data("#!/bin/bash\nexec openssl enc -aes-128-cbc -d -a -md sha256 #{derive.shelljoin} -pass env:#{passphrase_env_name} <<< #{encrypted_password.shellescape}\n")
            ch.eof!
          end

          sh = "#{passphrase_env_name}=#{temporary_passphrase.shellescape} SUDO_ASKPASS=#{temp_executable.shellescape} sudo -A "
          exp = "export #{passphrase_env_name}=#{temporary_passphrase.shellescape}\nexport SUDO_ASKPASS=#{temp_executable.shellescape}\n"
          cmd = "sudo -A "
          yield sh, exp, cmd

        ensure
          ssh_run("shred --remove #{temp_executable.shellescape}")
        end
      end

      def set_ssh_output_hook(c)
        check = ->(prefix, data, buf) do
          data = buf + data unless buf.empty?
          return if data.empty?

          lines = data.lines

          # If data is not NL-terminated, its last line is carried over to next check.call
          if lines.last.end_with?("\n")
            buf.clear
          else
            buf.replace(lines.pop)
          end

          lines.each do |line|
            puts "#{prefix}#{line}"
          end
        end

        outbuf, errbuf = +"", +""
        outpre, errpre = "[#{host.name}] ", "[#{host.name}/ERR] "

        c.on_data do |c, data|
          check.call outpre, data, outbuf
        end
        c.on_extended_data do |c, _, data|
          check.call errpre, data, errbuf
        end
        c.on_close do
          puts "#{outpre}#{outbuf}" unless outbuf.empty?
          puts "#{errpre}#{errbuf}" unless errbuf.empty?
        end
      end

      def host_basedir
        @host_basedir || "#{host_tmpdir}/itamae"
      end

      def host_shm_basedir
        host_shmdir && "#{host_shmdir}/itamae"
      end

      def host_shmdir
        return @host_shmdir if @host_shmdir
        return nil if @host_shmdir == false

        shmdir = host.shmdir
        unless shmdir
          if ssh.exec!('uname').chomp == 'Linux'
            shmdir = '/dev/shm'
            mount = ssh.exec!("grep -F #{shmdir.shellescape} /proc/mounts").each_line.map{ |_| _.chomp.split(' ') }
            unless mount.find { |_| _[1] == shmdir }&.first == 'tmpfs'
              @host_shmdir = false
              return nil
            end
          else
            @host_shmdir = false
            return nil
          end
        end

        mktemp_cmd = "TMPDIR=#{shmdir.shellescape} #{%w(mktemp -d -t hocho-run-XXXXXXXXX).shelljoin}"

        res = ssh.exec!(mktemp_cmd)
        unless res.start_with?(shmdir)
          raise "Failed to shm mktemp #{mktemp_cmd.inspect} -> #{res.inspect}"
        end
        @host_shmdir = res.chomp
      end

      def host_tmpdir
        @host_tmpdir ||= begin
          mktemp_cmd = %w(mktemp -d -t hocho-run-XXXXXXXXX).shelljoin
          mktemp_cmd.prepend("TMPDIR=#{host.tmpdir.shellescape} ") if host.tmpdir

          res = ssh.exec!(mktemp_cmd)
          unless res.start_with?(host.tmpdir || '/')
            raise "Failed to mktemp #{mktemp_cmd.inspect} -> #{res.inspect}"
          end
          res.chomp
        end
      end

      def remove_host_tmpdir!
        if @host_tmpdir
          host_tmpdir, @host_tmpdir = @host_tmpdir, nil
          ssh.exec!("rm -rf #{host_tmpdir.shellescape}")
        end
      end

      def remove_host_shmdir!
        if @host_shmdir
          host_shmdir, @host_shmdir = @host_shmdir, nil
          ssh.exec!("rm -rf #{host_shmdir.shellescape}")
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
