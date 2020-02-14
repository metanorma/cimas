module Cimas
  class Repository
    attr_reader :name, :remote, :branch, :files

    def initialize(name, attributes = {})
      init_from_attributes(name, attributes)
    end

    def nil?
      remote == nil && branch == nil
    end

    private

    def init_from_attributes(name, attributes)
      if attributes
        @name = name

        @remote = attributes.fetch("remote", nil)
        @branch = attributes.fetch("branch", nil)
        @files = attributes.fetch("files", nil)
      end
    end
  end
end
