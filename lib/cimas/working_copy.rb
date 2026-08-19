require "git"
require "open3"

module Cimas
  # Deep module over one repository's working copy: every git-gem call,
  # exception rescue, and porcelain/CLI parsing the orchestrator needs
  # lives behind ~10 domain verbs. Subcommands then read as wave prose
  # instead of git incantations.
  class WorkingCopy
    def self.open(dir)
      new(Git.open(dir))
    end

    def self.clone(remote, name, path:)
      Git.clone(remote, name, path: path)
    end

    def initialize(git)
      @git = git
    end

    def head_sha
      @git.object("HEAD").sha
    end

    def remote_name
      @git.remotes.first.to_s
    end

    # True when the working copy has any uncommitted change.
    def drift?
      out, = Open3.capture3("git", "-C", dir, "status", "--porcelain")
      !out.strip.empty?
    rescue StandardError
      false
    end

    # checkout + reset_hard + clean: the "start from a pristine branch"
    # preamble of sync and cleanup-orphan-files.
    def reset_clean(branch, include_untracked: false)
      checkout(branch)
      @git.reset_hard(branch)
      @git.clean(force: true, d: include_untracked)
    end

    def stage(*paths)
      paths.each { |path| @git.add(path) }
    end

    def remove(*paths)
      paths.each { |path| @git.remove(path) }
    end

    # True when nothing is staged or modified — push skips the
    # commit in this case.
    def clean?
      status = @git.status
      status.changed.empty? && status.added.empty? && status.deleted.empty?
    end

    def commit_all(message)
      @git.commit_all(message)
    end

    def commit(message)
      @git.commit(message)
    end

    # push's keep_changes=false preamble: stand on the base branch,
    # soft-reset onto it, and discard an existing branch of the given
    # name so it can be provisioned fresh.
    def reset_onto(base, discard_branch: nil)
      checkout(base)
      @git.reset(base)
      @git.branch(discard_branch).delete if discard_branch && @git.is_branch?(discard_branch)
    end

    # Switch to a branch; :fresh discards an existing branch of the same
    # name first (cleanup-orphan-files' shape).
    def switch_branch(name, fresh: false)
      @git.branch(name).delete if fresh && @git.is_branch?(name)
      @git.branch(name).checkout
    end

    # pull's dance: fetch origin, best-effort reset (a fresh clone may
    # not hold the branch ref yet), checkout, pull.
    def fetch_reset_pull(branch)
      @git.remote("origin").fetch
      begin
        @git.reset_hard(branch)
      rescue Git::Error
        # reset can fail when the branch ref is absent on a fresh
        # clone; checkout/pull below still applies.
        nil
      end
      checkout(branch)
      @git.pull("origin", branch)
    end

    # Returns :pushed, :behind_remote (non-force push behind the remote
    # tip), or [:rejected, error]. The caller decides presentation.
    # "Updates were rejected" covers both the classic git phrasing
    # ("tip of your current branch is behind") and the modern one ("the
    # remote contains work that you do not have locally").
    def push(branch, force: false, remote: nil)
      @git.push(remote || remote_name, branch, force: force)
      :pushed
    rescue Git::GitExecuteError, Git::FailedError => e
      if e.message.match?(/Updates were rejected/)
        :behind_remote
      else
        [:rejected, e]
      end
    end

    def diff_patch
      @git.diff.patch
    end

    def each_staged_change
      @git.status.changed.each do |file, status|
        yield(file, status.blob(:index).contents)
      end
    end

    private

    def checkout(branch)
      @git.checkout(branch)
    end

    def dir
      @git.dir.to_s
    end
  end
end
