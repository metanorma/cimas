require "octokit"

module Cimas
  # Octokit boundary: client construction, remote-to-slug mapping, and
  # the visibility-lookup fallback policy live here; the orchestrator
  # speaks in slugs.
  class GitHub
    def initialize(token: nil)
      @token = token
    end

    def client
      if @token.nil?
        raise "[ERROR] Please set GITHUB_TOKEN environment variable to use GitHub functions."
      end
      @client ||= Octokit::Client.new(access_token: @token)
    end

    # Maps any GitHub remote form (ssh://git@github.com/org/repo,
    # git@github.com:org/repo.git, https://github.com/org/repo.git) to
    # the `org/repo` slug Octokit expects.
    def slug_for(remote)
      match = remote.to_s.match(%r{github\.com[/:](.+?)(?:\.git)?\z})
      unless match
        raise "[ERROR] not a GitHub remote: #{remote.inspect} — cimas only operates on GitHub repositories."
      end

      match[1]
    end

    # True when the repo is GitHub-private. Falls back to `true` (no
    # accidental public template picks) when the API is unreachable.
    def fetch_visibility(slug)
      client.repo(slug).private
    rescue Octokit::NotFound
      puts "[WARNING] Cannot fetch visibility for #{slug} (404); defaulting to `private` (safer)."
      true
    rescue StandardError => e
      puts "[WARNING] Visibility fetch failed for #{slug}: #{e.message}; defaulting to `private` (safer)."
      true
    end
  end
end
