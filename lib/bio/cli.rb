require 'tomlrb'
require 'mixlib/cli'
require 'pp'

require 'bio/ui'
require 'bio/sdk/version'

STDOUT.sync = true

module Bio
  # This basic class defines all required behavior for cli commands
  class CLI
    include Mixlib::CLI
    include Bio::UI

    # Config loaded from plan.toml
    attr_accessor :user_config

    # Merged config used to run
    attr_accessor :run_config

    option :plan_context,
      long: '--plan-context DIR',
      default: '.',
      on: :tail,
      description: 'Dir with plan.sh or habitat directory. Defaults to current directory.'

    option :plan_toml,
      long: '--plan-toml FILE',
      default: 'plan.toml',
      on: :tail,
      description: 'Path to toml config. Relative to plan context. Optional'

    option :debug,
      long: '--debug',
      boolean: true,
      on: :tail,
      description: 'Debugs configuration and commands.'

    # List options is used for array or list in configuration and cli
    # Usually I want to define add-<thing> and remove-<thing>:
    # Library can have its default values and I don't want actually to
    # replace all default, but want to add few more and/or maybe exclude something
    def self.list_option(name, default = [])
      option :"add-#{name}",
        long: "--add-#{name} item1,item2,..",
        default: default,
        proc: ->(x) { x.split(',').map(&:strip).uniq },
        description: "Add item to #{name} list. Default: #{default}"

      option :"remove-#{name}",
        long: "--remove-#{name} item1,item2,..",
        default: [],
        proc: ->(x) { x.split(',').map(&:strip).uniq },
        description: "Remove item from #{name} list"
    end

    def initialize(*args)
      super(*args)

      @user_config = Hash.new
      @run_config = Hash.new
    end

    def make!
      raise "You must override me in #{self}"
    end

    def run
      version_string
      parse_options
      ensure_plan_context! rescue exit 42
      load_user_config
      make_run_config

      debug_config if config[:debug] || user_config[:debug]

      make!
    end

    # Wrapper to properly run shell out command:
    # @param [*] arguments for shellout
    # @return [Mixlib::ShellOut]
    def shellout(*cmd)
      so = Mixlib::ShellOut.new(*cmd)
      so.live_stdout = $stdout
      so.live_stderr = $stderr

      so.cwd = run_config[:plan_context]

      debug_section('Running Command', so.command) if run_config[:debug]
      so.run_command

      message "Took #{so.execution_time} sec." if run_config[:debug]

      so
    end

    def version_string
      header "The Biome #{File.basename($PROGRAM_NAME)}: #{Bio::SDK::VERSION}"
    end

    # Adjusts and checks plan context
    def ensure_plan_context!
      pc = cli_arguments.first || config[:plan_context] || default_config[:plan_context]
      pc = File.expand_path(pc)

      pc = "#{pc}/habitat" if File.exist?("#{pc}/habitat/plan.sh")

      unless File.exist?("#{pc}/plan.sh")
        warning "Plan context was not found!"
        raise "Plan context was not found!"
      end

      Dir.chdir pc

      config[:plan_context] = pc
      note "Found plan context at #{config[:plan_context]}."
    end

    # Each cli uses its own section in plan.toml
    # This methods defines default section name.
    # Of course you can override this method
    def user_config_section
      $PROGRAM_NAME.sub(/.*bio-plan-/, '').to_sym
    end

    def load_user_config
      plan_toml = [
        config[:plan_toml],
        default_config[:plan_toml],
        File.join('..', default_config[:plan_toml]),
        File.join('..', '..', default_config[:plan_toml]),
        File.join('..', '..', '..', default_config[:plan_toml])
      ].compact.map { |pt| File.expand_path(pt, config[:plan_context]) }

      plan_toml = plan_toml.find { |pt| File.exist?(pt) }

      @user_config = {}
      unless plan_toml
        warning "Ignoring absent plan.toml at #{config[:plan_toml]}" if config[:plan_toml]
        return
      end

      config[:plan_toml] = plan_toml

      begin
        @user_config = Tomlrb.load_file(plan_toml, symbolize_keys: true)
        @user_config = @user_config[user_config_section] || {}
      rescue Tomlrb::ParseError => e
        warning "Unable to load provided toml: #{e.message.gsub("\n", ' ')}"
      rescue RuntimeError => e
        warning "Unexpected error during load user config: #{e.message}"
      end
    end

    def make_run_config
      merge_configs(run_config, default_config)
      merge_configs(run_config, user_config)
      merge_configs(run_config, config)
    end

    # Merges config b into a
    # It overrides default values but concatenates arrays
    def merge_configs(a, b)
      b.each_pair do |k, v|
        case v
        when Array
          a[k] = [v, a[k]].flatten.compact.uniq
        else
          a[k] = b[k]
        end
      end
    end

    def debug_config
      debug_section('Working Directory', Dir.pwd)
      debug_section('Default Config', default_config)
      debug_section('User Config', user_config)
      debug_section('Cli Config', config)
      debug_section('Run Config',run_config)
    end

    def merge_list_option(cfg, option)
      cfg[option] = cfg[:"add-#{option}"] - cfg[:"remove-#{option}"]
    end

    def glob_list_option(cfg, option, base)
      glob_list(cfg, :"add-#{option}", base)
      glob_list(cfg, :"remove-#{option}", base)
    end

    # Replaces in config globs with files
    # @param [Hash] cfg config
    # @param [Symbol] list list name
    # @param [String] base glob base
    def glob_list(cfg, list, base)
      cfg[list].map! { |x| Dir.glob(x, base: base) }
      cfg[list].flatten!
      cfg[list].uniq!
    end
  end
end
