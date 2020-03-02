require 'mixlib/shellout'
require 'bio/cli'

module Bio
  module Plan
    class RenderCheck < Bio::CLI
      banner "#{File.basename($PROGRAM_NAME)} [PLANCONTEXT] (options)"

      use_separate_default_options true

      list_option :template, %w[config/**/* hooks/*]
      list_option :suite, %w[tests/render/*]

      option :mock_data,
        long: '--mock-data FILENAME',
        default: 'mock-data.json',
        description: 'Defaults to mock-data.json in test case, its parent or plan context.'

      option :default_toml,
        long: '--default-toml FILENAME',
        default: 'default.toml',
        description: 'Defaults to default.toml in test case, its parent or plan context.'

      option :user_toml,
        long: '--user-toml FILENAME',
        default: 'user.toml',
        description: 'Defaults to user.toml in test case, its parent or plan context.'

      option :render,
        long: '--[no-]render',
        boolean: true,
        default: true,
        description: 'Defaults to write files to disk.'

      option :print,
        long: '--[no-]print',
        boolean: true,
        default: false,
        description: 'Defaults to not print to stdout.'

      option :quiet,
        long: '--[no-]quiet',
        boolean: true,
        default: true,
        description: 'Defaults to be quiet.'


      def make!
        glob_list_option(run_config, :template, run_config[:plan_context])
        glob_list_option(run_config, :suite, run_config[:plan_context])

        merge_list_option(run_config, :template)
        merge_list_option(run_config, :suite)

        run_config[:suite].reject! {|s| !File.directory?(s)}
        run_config[:suite] = ['tests/render/default'] if run_config[:suite].empty?

        run_config[:suite].each do |suite|
          header "Rendering suite #{suite}"

          run_config[:template].each do |template|
            note "Rendering #{template}"

            exit 1 unless render_template(template, suite)
          end
        end

        run_config[:suite].each do |suite|
          header "Validating suite #{suite}"

          run_config[:template].each do |template|
            note "Validating #{template}"

            exit 1 unless validate_template(template, suite)
          end
        end
      ensure
        ensure_permissions
      end

      def render_template(template, suite)
        render_dir = File.join(run_config[:results_dir], suite, File.dirname(template))

        default_toml = resolve_file(suite, run_config[:default_toml])
        mock_data = resolve_file(suite, run_config[:mock_data])
        user_toml = resolve_file(suite, run_config[:user_toml])

        cmd = [
          run_config[:bio_cli], 'plan', 'render',
          '--render-dir', render_dir,
          ('--no-render' unless run_config[:render]),
          ('--print' if run_config[:print]),
          ('--quiet' if run_config[:quiet]),
          ("--default-toml #{default_toml}" if default_toml),
          ("--mock-data #{mock_data}" if mock_data),
          ("--user-toml #{user_toml}" if user_toml),
          template
        ].compact.join(' ')

        shellout(cmd).exitstatus == 0
      end

      def validate_template(template, suite)
        expected_template = File.join(run_config[:plan_context], suite, template)
        actual_template = File.join(run_config[:results_dir], suite, template)

        return true unless File.exist?(expected_template)

        cmd = [
          'diff', expected_template, actual_template
        ].join(' ')

        shellout(cmd).exitstatus == 0
      end

      # Try to find appropriate file by searching in suite directory, suites' parent or plan context
      # @param [String] suite directory with render test case
      # @param [String] filename to resolve
      # @return [String] path to file in suite or plan context or nil
      def resolve_file(suite, filename)
        [
          File.join(run_config[:plan_context], suite, filename),
          File.expand_path(File.join(run_config[:plan_context], suite, '..', filename)),
          File.join(run_config[:plan_context], filename)
        ].find {|f| File.exist?(f)}
      end
    end
  end
end
