require 'hocho/drivers/ssh_base'

module Hocho
  module Drivers
    class Bundler < SshBase
      def initialize(host, base_dir: '.', initializers: [], itamae_options: [], bundle_without: [], bundle_path: nil,
                     deploy_options: {}, keep_synced_files: false, **)
        super host, base_dir: base_dir, initializers: initializers

        @itamae_options = itamae_options
        @bundle_without = bundle_without
        @bundle_path = bundle_path
        @deploy_options = deploy_options
        @keep_synced_files = keep_synced_files
      end

      def run(dry_run: false)
        ssh # Test connection
        deploy(**@deploy_options) do
          bundle_install
          run_itamae(dry_run: dry_run)
        end
      end


      def bundle_install
        bundle_path_env = @bundle_path ? "BUNDLE_PATH=#{@bundle_path.shellescape} " : nil
        check_exitstatus, check_exitsignal = ssh_run("cd #{host_basedir.shellescape} && #{bundle_path_env}bundle check", error: false)
        return if check_exitstatus == 0

        prepare_sudo do |sh, sudovars, sudocmd|
          bundle_install = [host.bundler_cmd, 'install']
          bundle_install.push('--path', @bundle_path) if @bundle_path
          bundle_install.push('--without', [*@bundle_without].join(?:)) if @bundle_without

          puts "=> #{host.name} # #{bundle_install.shelljoin}"

          ssh_run("bash") do |c|
            set_ssh_output_hook(c)

            c.send_data("cd #{host_basedir.shellescape}\n#{sudovars}\n#{sudocmd}#{bundle_install.shelljoin}\n")
            c.eof!
          end
        end
      end

      def run_itamae(dry_run: false)
        with_host_node_json_file do
          itamae_cmd = ['itamae', 'local', '-j', host_node_json_path, *@itamae_options]
          itamae_cmd.push('--dry-run') if dry_run
          itamae_cmd.push('--color') if $stdout.tty?
          itamae_cmd.push(*run_list)

          prepare_sudo do |sh, sudovars, sudocmd|
            puts "=> #{host.name} # #{host.bundler_cmd} exec #{itamae_cmd.shelljoin}"
            ssh_run("bash") do |c|
              set_ssh_output_hook(c)

              c.send_data("cd #{host_basedir.shellescape}\n#{sudovars}\n#{sudocmd}#{host.bundler_cmd} exec #{itamae_cmd.shelljoin}\n")
              c.eof!
            end
          end
        end
      end
    end
  end
end
