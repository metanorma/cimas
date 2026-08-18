module Cimas
  # Value object over one `patches:` entry in cimas.yml — an in-place
  # regex find/replace applied to files already present in each target
  # repo (unlike `files:` sync, which replaces whole files). See the
  # Patches section of README.adoc.
  class Patch
    attr_reader :name, :globs, :find_regexp, :replacement, :group_names

    def initialize(name, attributes)
      @name = name
      @globs = Array(attributes["files"])
      @find_regexp = Regexp.new(attributes["find"])
      @replacement = attributes["replace"]
      @group_names = attributes["groups"] || []
    end

    def matches?(content)
      find_regexp.match?(content)
    end

    def apply(content)
      content.gsub(find_regexp, replacement)
    end
  end
end
