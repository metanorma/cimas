module Cimas
  module Cli
    autoload :Command, File.expand_path("cli/command", __dir__)
    autoload :Error, File.expand_path("cli/error", __dir__)
    autoload :Runner, File.expand_path("cli/runner", __dir__)
  end
end
