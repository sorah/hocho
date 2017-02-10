require 'hocho/drivers/ssh_base'

module Hocho
  module Drivers
    class Mitamae < SshBase
      def initialize(host, base_dir: '.', mitamae_path: 'mitamae', mitamae_prepare_script: [], mitamae_outdate_check_script: nil, initializers: [], mitamae_options: [], deploy_options: {})
        super host, base_dir: base_dir, initializers: initializers

        @mitamae_path = mitamae_path
        @mitamae_prepare_script = mitamae_prepare_script
        @mitamae_outdate_check_script = mitamae_outdate_check_script
        @mitamae_options = mitamae_options
        @deploy_options = deploy_options
      end


      def run(dry_run: false)
        deploy(**@deploy_options) do
          prepare_mitamae
          run_mitamae(dry_run: dry_run)
        end
      end

      def mitamae_available?
        exitstatus, _ = if @mitamae_path.start_with?('/')
          ssh_run("test -x #{@mitamae_path.shellescape}", error: false)
        else
          ssh_run("which #{@mitamae_path.shellescape} 2>/dev/null >/dev/null", error: false)
        end
        exitstatus == 0
      end

      def mitamae_outdated?
        if @mitamae_outdate_check_script
          exitstatus, _ = ssh_run("export HOCHO_MITAMAE_PATH=#{@mitamae_path.shellescape}; #{@mitamae_outdate_check_script}", error: false)
          exitstatus == 0
        else
          false
        end
      end

      def prepare_mitamae
        return if mitamae_available? && !mitamae_outdated?
        script = [*@mitamae_prepare_script].join("\n\n")
        if script.empty?
          raise "We have to prepare MItamae, but not mitamae_prepare_script is specified"
        end
        prepare_sudo do |sh, sudovars, sudocmd|
          log_prefix = "=> #{host.name} # "
          log_prefix_white = ' ' * log_prefix.size
          puts "#{log_prefix}#{script.each_line.map{ |_| "#{log_prefix_white}#{_.chomp}" }.join("\n")}"

          ssh_run("bash") do |c|
            set_ssh_output_hook(c)

            c.send_data("cd #{host_basedir.shellescape}\n#{sudovars}\n#{sudocmd} bash <<-'HOCHOEOS'\n#{script}HOCHOEOS\n")
            c.eof!
          end
        end
        availability, outdated = mitamae_available?, mitamae_outdated?
        if !availability || outdated
          status = [availability ? nil : 'unavailable', outdated ? 'outdated' : nil].compact.join(' and ')
          raise "prepared MItamae, but it's still #{status}"
        end
      end

      def run_mitamae(dry_run: false)
        with_host_node_json_file do
          itamae_cmd = [@mitamae_path, 'local', '-j', host_node_json_path, *@mitamae_options]
          itamae_cmd.push('--dry-run') if dry_run
          # itamae_cmd.push('--color') if $stdout.tty?
          itamae_cmd.push(*run_list)

          prepare_sudo do |sh, sudovars, sudocmd|
            puts "=> #{host.name} # #{itamae_cmd.shelljoin}"
            ssh_run("bash") do |c|
              set_ssh_output_hook(c)

              c.send_data("cd #{host_basedir.shellescape}\n#{sudovars}\n#{sudocmd} #{itamae_cmd.shelljoin}\n")
              c.eof!
            end
          end
        end
      end
    end
  end
end
