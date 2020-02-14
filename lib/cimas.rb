require "cimas/version"
require "cimas/cli/command"
require "cimas/repository"

module Cimas
  def self.root
    File.dirname(__dir__)
  end

  def self.root_path
    Pathname.new(Cimas.root)
  end
end
