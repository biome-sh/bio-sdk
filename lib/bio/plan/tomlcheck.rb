require 'mixlib/shellout'
require 'bio/cli'

module Bio
  module Plan
    class TomlCheck < Bio::CLI
      banner "#{File.basename($PROGRAM_NAME)} [PATH] (options)"

      use_separate_default_options true
      list_option :path, [
        'default.toml',
        'plan.toml',
        '../plan.toml',
        '../../plan.toml',
        '../../../plan.toml'
      ]

      def make!
        glob_list_option(run_config, :path, run_config[:plan_context])
        merge_list_option(run_config, :path)

        if run_config[:path].empty?
          message 'No toml files were found. Skipping.'
          exit 0
        end

        cmd = [
          'tomlcheck',
          '-f', run_config[:path].join(' -f ')
        ].join(' ')

        exit shellout(cmd).exitstatus
      end
    end
  end
end
