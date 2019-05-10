module Bio
  module UI
    def header(str)
      puts "=> #{str}"
    end

    def warning(str)
      puts " * -> #{str} <- *"
    end

    def note(str)
      puts " * #{str}"
    end

    def message(str)
      puts "   #{str}"
    end

    def debug_section(title, str)
      str = str.pretty_inspect.chomp

      title = "= #{title} ====".rjust(80, '=')
      footer = '-' * title.length

      puts [title, str, footer, '', ''].join("\n")
    end
  end
end
