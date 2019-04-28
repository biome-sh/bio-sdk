require 'mixlib/shellout'
require 'hab/cli'

module Hab
  module Plan
    class ShellCheck < Hab::CLI
      banner "#{File.basename($PROGRAM_NAME)} [PATH] (options)"

      use_separate_default_options true
      list_option :path, %w[plan.sh hooks/* lib/*]
      list_option :exclude, %w[SC1090 SC1091 SC2034]

      option :'external-sources',
        long: '--[no-]external-sources',
        boolean: true,
        default: true,
        description: "Allow 'source' outside of FILES. Default: true"

      option :format,
        long: '--format FORMAT',
        in: %w[checkstyle gcc json tty],
        description: 'Output format.'

      option :shell,
        long: '--shell DIALECT',
        in: %w[sh bash dash ksh],
        description: 'Specify dialect.'

      option :'color',
        long: '--[no-]color',
        boolean: true,
        default: true,
        description: 'Color output. Default: true'

      def make!
        glob_list_option(run_config, :path, run_config[:plan_context])
        merge_list_option(run_config, :path)
        merge_list_option(run_config, :exclude)

        if run_config[:path].empty?
          message 'No shell files were found. Skipping.'
          exit 0
        end

        cmd = [
          'shellcheck',
          ('--external-sources' if run_config[:'external-sources']),
          ("--format #{run_config[:format]}" if run_config[:format]),
          ("--shell #{run_config[:shell]}" if run_config[:shell]),
          ("--color" if run_config[:color]),
          ("--exclude #{run_config[:exclude].join(',')}" unless run_config[:exclude].empty?),
          run_config[:path].join(' ')
        ].join(' ')

        exit shellout(cmd).exitstatus
      end
    end
  end
end
