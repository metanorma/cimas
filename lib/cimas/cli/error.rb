module Cimas
  module Cli
    # A user-facing error: bad options, refused scope, missing config.
    # The executable prints one clean line and exits 1; anything else is
    # an internal error and keeps its backtrace.
    class Error < StandardError; end
  end
end
