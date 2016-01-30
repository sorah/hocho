require 'hocho/drivers/base'
require 'shellwords'

module Hocho
  module Drivers
    class ItamaeSsh < Base
      def initialize(host, base_dir: '.', initializers: [], itamae_options: [])
        super host, base_dir: base_dir, initializers: initializers
        @itamae_options = itamae_options
      end

      def run(dry_run: false)
        with_node_json_file do |node_json|
          env = {}.tap do |e|
            e['SUDO_PASSWORD'] = host.sudo_password if host.sudo_password
          end
          cmd = ["itamae", "ssh", *@itamae_options, "-j", node_json, "-h", host.hostname]

          cmd.push('-u', host.user) if host.user
          cmd.push('-p', host.ssh_port.to_s) if host.ssh_port
          cmd.push('--dry-run') if dry_run
          cmd.push('--color') if $stdout.tty?

          cmd.push(*run_list)

          puts "=> $ #{cmd.shelljoin}"
          system(env, *cmd, chdir: base_dir) or raise "itamae ssh failed"
        end
      end
    end
  end
end
