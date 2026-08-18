module Cimas
  # Finds files under a repo working copy that cimas generated (they
  # carry the generated header) but that the repo's current `files:`
  # mapping no longer lists — `sync`'s inverse. Pure logic: no config,
  # git, or GitHub access.
  module OrphanFiles
    # Bytes read per file when checking for the header — covers the
    # two-line header plus any leading shebang or comment; shorter
    # files read to EOF without error.
    HEADER_READ_BYTES = 500

    def self.find(repo_dir, mapped_targets, only_targets = nil)
      orphans = []
      Dir.glob(File.join(repo_dir, '**', '*'), File::FNM_DOTMATCH).each do |path|
        next unless File.file?(path)
        next if path.include?('/.git/') || path.end_with?('/.git')

        head = read_head(path)
        next unless head&.include?(Cimas::GENERATED_HEADER_MARKER)

        rel_path = path.sub("#{repo_dir}/", '')
        next if only_targets && !only_targets.include?(rel_path)

        orphans << rel_path unless mapped_targets.include?(rel_path)
      end
      orphans
    end

    def self.read_head(path)
      File.read(path, HEADER_READ_BYTES, encoding: 'UTF-8')
    rescue ArgumentError, EncodingError, SystemCallError
      # Binary, malformed encoding, or unreadable — cimas only writes
      # text files, so these cannot be cimas-managed.
      nil
    end
  end
end
