module Cimas
  # Value object over one `repositories:` entry in cimas.yml. Always built
  # with real attributes — unknown repo names are the caller's problem
  # (see `Cli::Command#repo_by_name`, which returns nil for them).
  class Repository
    attr_reader :name, :remote, :branch, :files, :binding, :with_values

    def initialize(name, attributes = {})
      @name = name

      @remote = attributes.fetch("remote", nil)
      @branch = attributes.fetch("branch", nil)
      # `files:` in cimas.yml is typically a Hash (`local_path: template_path`),
      # but some entries use `files: []` (a YAML empty Array) to signal
      # "no sync mappings — track the repo but don't touch any file."
      # Normalise both shapes to a Hash so downstream `#files.keys` works.
      raw_files = attributes.fetch("files", nil)
      @files = raw_files.is_a?(Array) ? {} : (raw_files || {})
      # Hash#dig doesn't accept a block — the `{ {} }` in the prior
      # version was silently ignored, so absent `template: binding:`
      # yielded `nil`. Explicit `|| {}` keeps the type stable (always a
      # Hash); the sole consumer at `Cli::Command#sync` wraps it in an
      # OpenStruct where nil and {} behave identically, so this is a
      # correctness-not-behaviour fix.
      @binding = attributes.dig("template", "binding") || {}
      # `with:` is a per-repo top-level hash rendered into ERB templates
      # as `with_values`. Semantically intended for reusable-workflow
      # `with:` block inputs (per metanorma/ci#300 Gap 1) but the values
      # are just a Hash — usable for any parametric rendering.
      @with_values = attributes.fetch("with", {}) || {}
    end
  end
end
