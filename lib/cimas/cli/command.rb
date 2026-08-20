require 'yaml'
require 'octokit'
require 'ostruct'
require 'erb'
require 'fileutils'
require 'set'

module Cimas
  module Cli
    class Command
      DEFAULT_CONFIG = {
        'dry_run' => false,
        'verbose' => false,
        # nil, not ['all']: defaulting a wave to the whole fleet is how a
        # forgotten -g fans branches/PRs out to every repo in the config.
        # filtered_repo_names still falls back to all repos for local-only
        # commands; remote-mutating ones refuse at dispatch (see COMMANDS
        # and `execute`).
        'groups' => nil,
        'force_push' => false,
        'assignees' => [],
        'reviewers' => [],
        'keep_changes' => false,
        'add_auto_merge_label' => true,
        'cooldown_count' => 10,
        'cooldown_time' => 3 * 60
      }

      # One registry entry per subcommand, the single classification that
      # drives dispatch-time behavior:
      #   :remote_mutating — refuses to run without an explicit -g and
      #     prints a pre-flight scope line (provision branches, open PRs,
      #     delete branches, run arbitrary shell).
      #   :remote_mutating_if — same, but only when the mapped config
      #     flag opts in.
      #   :requires — config keys that must be set; validated eagerly at
      #     dispatch so a missing -b/-m fails fast instead of exiting 0
      #     when every repo happens to be skipped.
      #   :requires_if — additional required keys under a config flag.
      # Adding a subcommand = adding one entry here.
      COMMANDS = {
        'setup'                => {},
        'sync'                 => {},
        'diff'                 => {},
        'pull'                 => {},
        'push'                 => {
          remote_mutating: true,
          requires: %w[push_to_branch commit_message],
        },
        'open-prs'             => {
          remote_mutating: true,
          requires: %w[merge_branch pr_message],
        },
        'for-each'             => {
          remote_mutating: true,
          requires: %w[shell_cmd],
        },
        'cleanup-merged-prs'   => {
          remote_mutating: true,
          requires: %w[push_to_branch],
        },
        'cleanup-closed-prs'   => { remote_mutating: true },
        'cleanup-orphan-files' => {
          remote_mutating_if: 'cleanup_push_after',
          requires_if: ['cleanup_push_after', %w[push_to_branch pr_message]],
        },
        'release-preflight'    => { requires: %w[target_repo] },
      }.freeze

      # Config key → CLI flag spelling, for required-option messages.
      OPTION_FLAGS = {
        'push_to_branch' => '-b/--push-branch',
        'commit_message' => '-m/--message',
        'merge_branch' => '-b/--merge-branch',
        'pr_message' => '-m/--message',
        'shell_cmd' => '-c/--shell-cmd',
        'target_repo' => '--repo',
      }.freeze

      # How many repository names the pre-flight scope line lists before
      # collapsing to a count.
      SCOPE_LIST_LIMIT = 30

      def self.command_meta(command_name)
        COMMANDS[command_name] || {}
      end

      def self.remote_mutating?(command_name, config = {})
        meta = command_meta(command_name)
        return true if meta[:remote_mutating]

        flag = meta[:remote_mutating_if]
        !flag.nil? && config[flag] == true
      end

      def self.missing_required_options(command_name, config)
        meta = command_meta(command_name)
        required = meta[:requires] || []
        flag, conditional = meta[:requires_if] || [nil, []]
        required += conditional if flag && config[flag] == true
        required.reject { |key| config[key] }
      end

      def initialize(options)
        unless options['config_file_path'].exist?
          raise "[ERROR] config_file_path #{options['config_file_path']} does not exist, aborting."
        end

        @data = YAML.load(File.read(options['config_file_path'])) || {}

        unless repositories.is_a?(Hash) && !repositories.empty?
          raise "[ERROR] no `repositories:` section in #{options['config_file_path']} — nothing to operate on, aborting."
        end

        @config = DEFAULT_CONFIG.merge(settings || {}).merge(options)

        unless repos_path.exist?
          FileUtils.mkdir_p repos_path
        end

        if ENV["GITHUB_TOKEN"]
          @config['github_token'] ||= ENV["GITHUB_TOKEN"]
        end
      end

      # Single dispatch entrypoint (`exe/cimas` calls this). Scope guard,
      # required-option validation and the scope announcement all derive
      # from the one COMMANDS classification, so every remote-mutating
      # subcommand is guarded AND announces its blast radius uniformly,
      # and every required flag fails fast — before any repo iteration.
      # Calling a subcommand method directly bypasses the guard by design
      # — it protects CLI operators, not library callers.
      def execute(command_name)
        require_explicit_scope!(command_name)
        validate_required_options!(command_name)
        announce_scope(command_name) if self.class.remote_mutating?(command_name, config)

        public_send(command_name.tr('-', '_'))
      end

      def settings
        data['settings']
      end

      # Octokit boundary lives in Cimas::GitHub; these delegators keep
      # the orchestrator's vocabulary (slug from remote, cached
      # visibility per repository).
      # Inject a stand-in via config['github'] for offline specs;
      # production always builds a real Cimas::GitHub.
      def github
        @github ||= config['github'] || Cimas::GitHub.new(token: config['github_token'])
      end

      def github_client
        github.client
      end

      def git_remote_to_github_name(remote)
        github.slug_for(remote)
      end

      def fetch_repo_visibility(slug)
        github.fetch_visibility(slug)
      end

      # Returns true if the repo is GitHub-private, false if public.
      # Cached per invocation so a wave sync makes at most one call per
      # repo.
      def repo_visibility_private?(repo)
        @visibility_cache ||= {}
        slug = git_remote_to_github_name(repo.remote)
        return @visibility_cache[slug] if @visibility_cache.key?(slug)

        @visibility_cache[slug] = fetch_repo_visibility(slug)
      end

      def config
        @config
      end

      def data
        @data
      end

      def setup
        repositories.each_pair do |repo_name, attribs|
          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir) && File.exist?(File.join(repo_dir, '.git'))
            puts "Git cloning #{repo_name} from #{attribs['remote']}..."
            WorkingCopy.clone(attribs['remote'], repo_name, path: repos_path)
          else
            puts "Skip cloning #{repo_name}, #{repo_dir} already exists." if verbose
          end
        end
      end

      def sanity_check
        unsynced = []

        repositories.each_pair do |repo_name, attribs|
          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir) && File.exist?(File.join(repo_dir, '.git'))
            unsynced << repo_name
          end
        end

        unsynced.uniq!

        return true if unsynced.empty?

        # Advisory only — execution continues (pure-API commands such as
        # cleanup-merged-prs legitimately run with no clones present).
        warn "[WARNING] These repositories have not been setup, please run `setup` first: #{unsynced.inspect}"
      end

      def config_master_path
        config['config_master_path']
      end

      def repos_path
        config['repos_path']
      end

      def repositories
        data['repositories']
      end

      def verbose
        config['verbose']
      end

      def sync
        sanity_check
        unless config['config_master_path'].exist?
          raise "[ERROR] config_master_path not set, aborting."
        end

        each_target_repo('sync') do |repo, repo_dir|
          repo_name = repo.name

          dry_run("Copying files to #{repo_name} and staging them") do
            wc = WorkingCopy.open(repo_dir)

            wc.reset_clean(repo.branch) unless keep_changes

            puts "Syncing and staging files in #{repo_name}..."

            repo.files.each do |target, source|
              resolved_source = resolve_source(source, repo)
              source_path = File.join(config_master_path, resolved_source)
              target_path = File.join(repos_path, repo_name, target)
              puts "file #{source_path} => #{target_path}" if verbose

              if source_path.end_with? ".erb"
                write_rendered(render_erb_template(source_path, repo), target_path)
              else
                copy_file(source_path, target_path)
              end

              wc.stage(target)
            end

            apply_patches(repo_name, repo_dir, wc)

            if verbose
              wc.each_staged_change do |_file, contents|
                puts "Updated files in #{repo_name}:"
                puts contents
              end
            end
          end
        end
      end

      def patches
        (data['patches'] || {}).map { |name, attrs| Cimas::Patch.new(name, attrs) }
      end

      def apply_patches(repo_name, repo_dir, working_copy)
        patches.each do |patch|
          target_repo_names = patch.group_names.flat_map { |g| group_repo_names(g) }.uniq
          next unless target_repo_names.include?(repo_name)

          patch.globs.each do |glob|
            matched = Dir.glob(File.join(repo_dir, glob))
            if matched.empty?
              puts "[WARNING] Patch '#{patch.name}' on #{repo_name}: no files matched glob '#{glob}'."
              next
            end

            matched.each do |file_path|
              rel_path = file_path.sub(/\A#{Regexp.escape(repo_dir)}\/?/, '')
              original = File.read(file_path)
              # Distinguish two cases that previously both logged the same
              # misleading "pattern did not match, file unchanged" warning
              # (see metanorma/cimas#49 Bug 3):
              #   - `find` regex doesn't appear in the file at all (the line
              #     this patch wants to update is genuinely absent — e.g. a
              #     gemspec with no `required_ruby_version` line, the NOVER
              #     case). WARNING-level: maintainer may want to add the line.
              #   - `find` matches but gsub produces identical text (the
              #     file is already at the target value). INFO-level: this is
              #     a normal idempotent no-op, not a problem.
              unless patch.matches?(original)
                puts "[WARNING] Patch '#{patch.name}' on #{repo_name}:#{rel_path}: pattern not present in file (line absent — consider whether the patch should also handle insertion)."
                next
              end

              updated = patch.apply(original)
              if original == updated
                puts "[INFO] Patch '#{patch.name}' on #{repo_name}:#{rel_path}: already at target value, no-op."
                next
              end

              dry_run("Patching #{rel_path} in #{repo_name} (patch '#{patch.name}')") do
                File.write(file_path, updated)
                working_copy.stage(rel_path)
              end
            end
          end
        end
      end

      def diff
        sanity_check

        each_target_repo('diff') do |repo, repo_dir|
          puts "======================= DIFF FOR #{repo.name} ========================="
          puts WorkingCopy.open(repo_dir).diff_patch
        end
      end

      def filtered_repo_names
        @filtered_repo_names ||= if config['groups']
                                   config['groups'].inject([]) do |acc, group|
                                     acc + group_repo_names(group)
                                   end.uniq
                                 else
                                   repositories.keys
                                 end
      end

      # Iterates the wave's resolved target repos, skipping any name that
      # is not a configured repository (`-g typo` resolves to a repo name
      # that cimas.yml doesn't define).
      def each_configured_repo
        filtered_repo_names.each do |repo_name|
          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          yield repo
        end
      end

      # `each_configured_repo` plus the clone-presence check, for commands
      # that operate on the working copy. Skip messages are uniform across
      # subcommands (`skipping <command> for it`).
      def each_target_repo(command_name)
        each_configured_repo do |repo|
          repo_dir = File.join(repos_path, repo.name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo.name} is missing in #{repos_path}, skipping #{command_name} for it."
            next
          end

          yield repo, repo_dir
        end
      end

      # Remote-mutating subcommands refuse to run unless -g is given and
      # resolves to at least one repository. Raises Cimas::Cli::Error so
      # the CLI reports a clean message without a backtrace.
      def require_explicit_scope!(command_name)
        return unless self.class.remote_mutating?(command_name, config)

        groups = config['groups']
        if groups.nil?
          raise Cimas::Cli::Error,
                "#{command_name}: no -g given — would target all " \
                "#{repositories.size} repositories in #{config['config_file_path']}. " \
                "Pass -g <group(s)> or -g <repo-name> to scope, or -g all to " \
                "target the whole fleet deliberately."
        end
        if groups.empty?
          raise Cimas::Cli::Error,
                "#{command_name}: -g given but empty (e.g. `-g ''`) — pass " \
                "-g <group(s)>, -g <repo-name>, or -g all to target the " \
                "whole fleet deliberately."
        end

        names = filtered_repo_names
        if names.empty?
          raise Cimas::Cli::Error,
                "#{command_name}: -g #{Array(groups).join(',')} resolves to 0 " \
                "repositories in #{config['config_file_path']} — check the " \
                "groups: section or the repo name."
        end
      end

      # Eager fail-fast for required flags, before any repo iteration —
      # lazy accessor validation alone let `push -g data` (no -b) exit 0
      # whenever every repo happened to be skipped.
      def validate_required_options!(command_name)
        missing = self.class.missing_required_options(command_name, config)
        return if missing.empty?

        flags = missing.map { |key| OPTION_FLAGS.fetch(key, key) }.join(', ')
        raise Cimas::Cli::Error,
              "#{command_name}: missing required option(s): #{flags}"
      end

      def announce_scope(command_name)
        names = filtered_repo_names
        label = if names.size <= SCOPE_LIST_LIMIT
                  names.join(', ')
                else
                  "(list omitted, >#{SCOPE_LIST_LIMIT} repos)"
                end
        puts "Scope for #{command_name}: #{names.size} repo(s): #{label}"
      end

      def repo_by_name(name)
        attributes = repositories[name]
        return nil unless attributes

        Cimas::Repository.new(name, attributes)
      end

      def pull
        sanity_check

        each_target_repo('pull') do |repo, repo_dir|
          dry_run("Pulling from #{repo.name}/#{repo.branch}...") do
            puts "Pulling from #{repo.name}/#{repo.branch}..."
            WorkingCopy.open(repo_dir).fetch_reset_pull(repo.branch)
          end
        end

        puts "Done!"
      end

      def commit_message
        msg = required_option('commit_message', '-m/--message')
        unless msg.include? "request-checks:"
          # https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks#checks
          # Thor freezes option strings — never mutate, always rebuild.
          msg = "#{msg}\n\nrequest-checks: true"
        end
        msg
      end

      def pr_message
        required_option('pr_message', '-m/--message')
      end

      def push_to_branch
        required_option('push_to_branch', '-b/--push-branch')
      end

      def merge_branch
        required_option('merge_branch', '-b/--merge-branch')
      end

      def shell_cmd
        required_option('shell_cmd', '-c/--shell-cmd')
      end

      def add_auto_merge_label
        config['add_auto_merge_label']
      end

      def force_push
        config['force_push']
      end

      def keep_changes
        config['keep_changes']
      end

      def push
        sanity_check
        drift_pushes = 0
        skipped_no_op = 0

        each_target_repo('push') do |repo, repo_dir|
          repo_name = repo.name
          wc = WorkingCopy.open(repo_dir)

          # Skip repos with no drift. The historical "always push even
          # without changes" behavior was there to guarantee the wave
          # branch exists on remote for the next-stage `cimas open-prs`.
          # But open_prs already handles missing wave branches gracefully
          # (see the /field: head\s+code: invalid/ rescue in
          # `open_prs`, which skips with a WARNING) and also handles the
          # "branch present but empty PR" case (/message: No commits
          # between/). So we can safely skip pushing wave branches for
          # repos that have no drift — the whole no-op notification-noise
          # class disappears without breaking open_prs.
          #
          # Assumes `cimas sync` has been run against this work-dir first,
          # so wd status reflects the drift state (matches the ordering
          # documented in README "End-to-end workflow").
          unless wc.drift?
            skipped_no_op += 1
            msg = "Skipping no-op push to #{repo_name} (no drift)"
            puts config['dry_run'] ? "dry run: #{msg}" : msg
            next
          end

          drift_pushes += 1

          dry_run("Pushing branch #{push_to_branch} (commit #{wc.head_sha}) to #{wc.remote_name}:#{repo_name}") do
            puts "repo.branch #{repo.branch}" if verbose

            wc.reset_onto(repo.branch, discard_branch: push_to_branch) unless keep_changes
            wc.switch_branch(push_to_branch)
            wc.stage(*repo.files.keys)

            if wc.clean?
              puts "Skipping commit on #{repo_name}, no changes detected." if verbose
            else
              puts "Committing on #{repo_name}."
              wc.commit_all(commit_message)
            end

            # Still push even if there was no commit, as the remote branch
            # may have been deleted. If the remote branch is deleted we can't
            # make PRs in the next stage. (Guard above ensures this branch
            # only runs when either the wd has drift OR the remote branch is
            # actually missing.)
            action = force_push ? "Force-pushing" : "Pushing"
            puts "#{action} branch #{push_to_branch} (commit #{wc.head_sha}) to #{wc.remote_name}:#{repo_name}."
            outcome = wc.push(push_to_branch, force: force_push)
            if outcome == :pushed
              nil
            elsif outcome == :behind_remote
              puts "[WARNING] branch #{push_to_branch} already exists on remote. If you wanna force push, pass --force"
            else
              _status, error = outcome
              puts "An error of type #{error.class} happened, message is #{error.message}"
            end
          end
        end

        puts ""
        puts "Push summary:"
        puts "  Pushed with drift: #{drift_pushes}"
        puts "  Skipped (no drift): #{skipped_no_op}"
      end

      # Label + comment (+ optionally close) a superseded prior-wave PR.
      # Called from the open_prs loop for each stale PR detected via
      # --supersede-stale / --flatten-stale (Gap 4 of metanorma/ci#300).
      def handle_superseded_pr(github_slug, stale, new_number, new_branch,
                               flatten:)
        label = flatten ? "superseded-closed-by-##{new_number}" \
                        : "superseded-by-##{new_number}"
        github_client.add_labels_to_an_issue(
          github_slug, stale.number, [label]
        )
        github_client.add_comment(
          github_slug, stale.number,
          supersede_comment_body(new_number, new_branch, flatten: flatten)
        )
        if flatten
          github_client.close_pull_request(github_slug, stale.number)
          puts "  flattened #{github_slug}##{stale.number} " \
               "(labelled + commented + closed)"
        else
          puts "  superseded #{github_slug}##{stale.number} " \
               "(labelled + commented)"
        end
      end

      def supersede_comment_body(new_number, new_branch, flatten:)
        if flatten
          "Auto-closed as superseded by ##{new_number} from a later " \
            "cimas-sync wave (`#{new_branch}`). If part of this PR's " \
            "content should have been preserved before flattening, " \
            "rebase this branch elsewhere and reopen. " \
            "(--flatten-stale, metanorma/ci#300 Gap 4 full)"
        else
          "Superseded by ##{new_number} from a later cimas-sync wave " \
            "(`#{new_branch}`). This PR was **not auto-closed** by cimas " \
            "— the reviewer keeps authority over the close decision. " \
            "Close after merging ##{new_number}, or rebase this branch " \
            "onto something else if part of its content should still be " \
            "preserved. (metanorma/ci#300 Gap 4)"
        end
      end

      # For metanorma/ci#347 Option B: a `files:` value can be either the
      # legacy String (a single template path) or a Hash of the shape
      # `{ 'if_public' => path1, 'if_private' => path2 }`. In the Hash
      # case, cimas picks the concrete template at sync time from the
      # target repo's GitHub visibility, so the same cimas.yml entry
      # tracks both public and private variants of e.g. docker.yml.
      # See ci#347 (private-vs-public docker split) for the design.
      def resolve_source(source, repo)
        return source unless source.is_a?(Hash)

        unless source.key?("if_public") && source.key?("if_private")
          raise "[ERROR] visibility-conditional source needs both " \
                "`if_public` and `if_private` keys; got: #{source.inspect}"
        end

        is_private = repo_visibility_private?(repo)
        is_private ? source["if_private"] : source["if_public"]
      end

      # PR body from --body-file (preferred), --body inline, or the
      # legacy "As title." placeholder. See metanorma/cimas#49 Bug 1: the
      # previous open-prs unconditionally used `-m` as the title and a
      # hard-coded body placeholder, so multi-line PR bodies were
      # impossible — and passing a long markdown body via `-m` made it
      # the title, triggering HTTP 422 "title is too long (max 256
      # chars)" and aborting the whole open-prs loop. Force UTF-8 on the
      # file read: locale-default (US-ASCII on some Ruby configs)
      # mis-tags the string, and Octokit → Sawyer → JSON.dump then blows
      # up on non-ASCII bytes (em dash, curly quotes) with `"\xE2" on
      # US-ASCII`. PR bodies are markdown and routinely contain UTF-8;
      # encoding-tagging at read time is the right place to fix it.
      def resolve_pr_body
        if config['pr_body_file'] && config['pr_body']
          raise Cimas::Cli::Error, "--body and --body-file are mutually exclusive"
        end

        if config['pr_body_file']
          File.read(config['pr_body_file'], encoding: 'UTF-8')
        elsif config['pr_body']
          config['pr_body'].dup.force_encoding('UTF-8')
        else
          "As title. \n\n _Generated by Cimas_."
        end
      end

      # GitHub rejects self-review requests with HTTP 422 "Review cannot
      # be requested from pull request author." Pre-filter the token
      # user out so the other reviewers still get requested (#7); when
      # the token user can't be resolved, proceed as configured.
      def reviewers_excluding_token_user(reviewers)
        token_user = github_client.user.login
        if reviewers.include?(token_user)
          puts "[INFO] open-prs: excluding token user " \
               "'#{token_user}' from reviewers (cannot self-review)"
          reviewers.reject { |r| r == token_user }
        else
          reviewers
        end
      rescue Octokit::Error => e
        puts "[WARNING] open-prs: could not resolve token user " \
             "for self-review filter (#{e.message}); " \
             "proceeding with reviewers as configured"
        reviewers
      end

      def open_prs
        sanity_check
        branch = merge_branch
        message = pr_message
        body = resolve_pr_body
        # Coerce to an Array of handles via string_list: accepts an Array
        # from cimas.yml settings or a (possibly comma-separated) String
        # from the `-a` / `-w` CLI flags. Without coercion, `-a opoudjis`
        # reached this block as a bare String and `.join(',')` further
        # down crashed with NoMethodError, aborting `cimas open-prs`
        # before any PR could be created.
        assignees = string_list(config['assignees'])
        reviewers = reviewers_excluding_token_user(string_list(config['reviewers']))

        cooldown_count = config['cooldown_count']
        cooldown_time = config['cooldown_time']

        cooldown_counter = 0

        each_target_repo('open-prs') do |repo, _repo_dir|
          repo_name = repo.name
          github_slug = git_remote_to_github_name(repo.remote)

          # --supersede-stale: detect prior open cimas-sync-* PRs on this repo.
          # See metanorma/ci#300 Gap 4. Cheaper-version (no strict-superset
          # check): we label-and-comment-but-do-not-close the old PRs, letting
          # the reviewer keep authority over the close decision. The new PR's
          # body is prepended with a "Supersedes #X, #Y" note so the reviewer
          # sees the full picture in the most recent PR.
          stale_prs = []
          if config['supersede_stale']
            begin
              stale_prs = github_client.pull_requests(github_slug, state: 'open').select do |stale|
                stale.head.ref.start_with?('cimas-sync-') && stale.head.ref != branch
              end
            rescue Octokit::Error => e
              puts "[WARNING] #{github_slug}: could not list open PRs for --supersede-stale (#{e.message}); proceeding without."
              stale_prs = []
            end
          end
          final_body = if stale_prs.any?
                         supersede_list = stale_prs.map { |p| "##{p.number}" }.join(", ")
                         "_Supersedes #{supersede_list} from prior cimas-sync waves._\n\n#{body}"
                       else
                         body
                       end

          dry_run("Opening GitHub PR: #{github_slug}, branch #{repo.branch} <- #{branch}, message '#{message}'") do
            puts "Opening GitHub PR: #{github_slug}, branch #{repo.branch} <- #{branch}, message '#{message}'"

            begin
              pr = github_client.create_pull_request(
                github_slug,
                repo.branch,
                branch,
                message,
                final_body,
              )
              number = pr['number']

              github_client.add_labels_to_an_issue(github_slug, number, ['automerge']) if add_auto_merge_label

              # Label-and-comment (--supersede-stale, Gap 4 cheaper) OR
              # label-and-comment-and-close (--flatten-stale, Gap 4 full).
              # The flatten-stale path auto-closes the superseded PRs on the
              # assumption that every cimas-sync wave regenerates the same
              # files from cimas.yml, so a newer wave strictly supersedes
              # any older wave's PR on the same repo.
              stale_prs.each do |stale|
                begin
                  handle_superseded_pr(
                    github_slug, stale, number, branch,
                    flatten: config['flatten_stale'] == true,
                  )
                rescue Octokit::Error => e
                  puts "  [WARNING] could not process supersede on " \
                       "#{github_slug}\##{stale.number}: #{e.message}"
                end
              end

              puts "PR #{github_slug}\##{number} created"

            rescue Octokit::Error => e
              case e.message
              when /A pull request already exists/
                puts "[WARNING] PR already exists for #{branch}."
                next

              when /field: head\s+code: invalid/
                puts "[WARNING] Branch #{branch} does not exist on #{github_slug}. Did you run `push`? Skipping."
                next

              when /message: No commits between/
                puts "[WARNING] Target branch (#{repo.branch}) is on par with new branch (#{branch}). Skipping."
                next

              when /Repository was archived so is read-only/
                puts "[WARNING] Reporitory #{branch} is readonly. Skipping."
                next

              else
                raise e
              end
            end

            unless pr
              puts "[WARNING] Detecting PR from GitHub..."
              github_branch_owner = github_slug.split('/').first
              prs = github_client.pull_requests(github_slug, head: "#{github_branch_owner}:#{branch}")
              pr = prs.first
              unless pr
                puts "[WARNING] Failed to detect PR from GitHub for #{github_slug} repo. Skipping."
                next
              end
              puts "[WARNING] Detected PR to be #{github_slug}\##{pr['number']}, continue processing."
            end

            number = pr['number']

            unless reviewers.empty?
              puts "Requesting #{github_slug}\##{number} review from: [#{reviewers.join(',')}]"
              begin
                github_client.request_pull_request_review(
                  github_slug,
                  number,
                  reviewers: reviewers
                )

              rescue Octokit::Error => e
                # TODO: When command is first run, should exclude the PR author from 'reviewers'
                case e.message
                when /Review cannot be requested from pull request author./
                  puts "[WARNING] #{e.message}, skipping."
                  next
                else
                  raise e
                end

              end
            end

            unless assignees.empty?
              puts "Assigning #{github_slug}\##{number} to: [#{assignees.join(',')}]"
              github_client.add_assignees(
                github_slug,
                number,
                assignees
              )
            end

            cooldown_counter += 1
            if cooldown_counter % cooldown_count == 0
              puts "Cool down for #{cooldown_time}sec to not abuse GitHub API..."
              sleep(cooldown_time)
            end
          end
        end
      end

      # Per-wave local cleanup: delete the branch named by `push_to_branch`
      # from each target repo on origin IF the corresponding PR has merged.
      # Open PRs are left alone (their branch is still in use). Branches with
      # no PR are deleted too (a wave that opened no PR for the repo, e.g.
      # because cimas detected "no commits" at push time, leaves a stale
      # branch on origin we shouldn't keep). Requires only standard `repo`
      # scope on each target repo — no admin scope, since branch deletion
      # against a merged PR is a push-level operation.
      def cleanup_merged_prs
        sanity_check
        branch = push_to_branch

        each_configured_repo do |repo|
          github_slug = git_remote_to_github_name(repo.remote)
          owner = github_slug.split('/').first

          begin
            prs = github_client.pull_requests(
              github_slug,
              head: "#{owner}:#{branch}",
              state: 'all'
            )
          rescue Octokit::Error => e
            puts "[ERROR] #{github_slug}: PR lookup failed (#{e.class}): #{e.message}"
            next
          end

          pr = prs.first

          if pr.nil?
            # No PR for this branch — attempt to delete if the branch exists
            delete_remote_branch(github_slug, branch, "no PR found")
            next
          end

          if pr.merged_at
            delete_remote_branch(github_slug, branch, "PR ##{pr.number} merged")
          elsif pr.state == 'open'
            puts "[skip-open] #{github_slug}:#{branch} (PR ##{pr.number} still open)"
          else
            # Closed-without-merge — keep branch by default; closing without merge
            # often means someone intends to revisit. Operator can clean up manually.
            puts "[skip-closed] #{github_slug}:#{branch} (PR ##{pr.number} closed without merge)"
          end
        end
      end

      # Sibling of `cleanup_merged_prs` for the closed-not-merged case.
      #
      # `cleanup_merged_prs` operates on ONE wave branch supplied via `-b`
      # and asks "did the PR merge? if so, delete the branch." This
      # subcommand operates on ALL branches whose names match a prefix
      # (default `cimas-sync-`), across the whole scope, and deletes the
      # ones whose PR was closed-without-merge — regardless of wave.
      #
      # Motivation (metanorma/ci#347 follow-up): when a wave PR is closed
      # without merge, cleanup-merged-prs leaves the branch alone by design
      # (someone may want to revisit). But wave PRs closed as superseded
      # (via `--flatten-stale`) or as unwanted (ci#347) accumulate orphan
      # branches on remotes. This sweeps them.
      #
      # Safety: only deletes branches whose head matches the prefix AND
      # whose PR is *closed* (state == 'closed', merged_at is nil). Open
      # PRs and merged PRs are left alone.
      def cleanup_closed_prs
        sanity_check
        prefix = config['cleanup_branch_prefix'] || 'cimas-sync-'

        each_configured_repo do |repo|
          github_slug = git_remote_to_github_name(repo.remote)

          # Page all closed PRs; API caps at 100/page but that's fine for
          # cimas-sync-* accumulation which is bounded by wave count.
          begin
            closed_prs = github_client.pull_requests(
              github_slug,
              state: 'closed',
              per_page: 100,
            )
          rescue Octokit::Error => e
            puts "[ERROR] #{github_slug}: PR lookup failed (#{e.class}): #{e.message}"
            next
          end

          candidates = closed_prs.select do |pr|
            pr.head&.ref&.start_with?(prefix) && pr.merged_at.nil?
          end

          if candidates.empty?
            puts "[none] #{github_slug}: no closed-not-merged '#{prefix}*' branches"
            next
          end

          candidates.each do |pr|
            delete_remote_branch(
              github_slug, pr.head.ref,
              "PR ##{pr.number} closed-not-merged #{pr.closed_at}"
            )
          end
        end
      end

      # Inverse of `sync`. Where `sync` writes cimas.yml-mapped files to
      # each repo's working tree, `cleanup_orphan_files` finds files that
      # (a) carry the Cimas auto-generated header comment, so they were
      # written by cimas at some point, and (b) are no longer in the
      # repo's `files:` mapping, so cimas is no longer regenerating them.
      # These files are orphans — they only exist because they were
      # sync'd on a prior config version and never cleaned up.
      #
      # Motivation (metanorma/ci#347 follow-up): dropping a file from a
      # repo's `files:` mapping (e.g. removing `.github/workflows/generate.yml`
      # from all non-mn-samples-* doc repos, per ci#347's docker-only rule)
      # stops future regeneration but leaves the existing file in the
      # repo, where its CI keeps failing. This subcommand purges those.
      #
      # Safety: only deletes files whose first ~500 bytes contain the
      # cimas header marker. Files without the header (custom CI, docs,
      # sources) are never touched.
      def cleanup_orphan_files
        sanity_check
        push_after = config['cleanup_push_after'] == true
        # `push_to_branch` / `pr_message` raise when their underlying config
        # key is nil, so only resolve them when `--push-after` actually needs
        # them. Without `--push-after` the subcommand is a local-only stage,
        # which is the correct shape for a dry-run scan or a review-before-blast
        # workflow.
        branch = push_after ? push_to_branch : nil
        message = push_after ? pr_message : nil
        # `--only-target=path[,path...]` narrows the sweep to specific target
        # paths so a wave can be scoped to just one class of orphan (e.g.
        # `.github/workflows/generate.yml` for the ci#347 cleanup). nil means
        # no filter — surface all orphan cimas-managed files.
        only_targets = config['cleanup_only_targets'] &&
                       string_list(config['cleanup_only_targets']).to_set

        each_target_repo('cleanup-orphan-files') do |repo, repo_dir|
          repo_name = repo.name
          wc = WorkingCopy.open(repo_dir)
          wc.reset_clean(repo.branch, include_untracked: true) unless keep_changes

          mapped_targets = (repo.files || {}).keys.to_set
          orphans = Cimas::OrphanFiles.find(repo_dir, mapped_targets, only_targets)

          if orphans.empty?
            puts "[clean] #{repo_name}"
            next
          end

          puts "[#{orphans.size} orphan(s)] #{repo_name}:"
          orphans.each { |o| puts "  - #{o}" }

          if push_after
            dry_run("Commit + push deletion of #{orphans.size} orphan(s) in #{repo_name} on #{branch}") do
              wc.switch_branch(branch, fresh: true)
              wc.remove(*orphans)
              wc.commit(message)
              if wc.push(branch, force: true) == :pushed
                puts "[pushed] #{repo_name}:#{branch}"
              else
                puts "[ERROR] #{repo_name}:#{branch} push failed"
              end
            end
          else
            # Local-only mode: stage the deletions for the operator to
            # inspect and push manually. Useful for a review-before-blast
            # workflow.
            dry_run("Stage deletion of #{orphans.size} orphan(s) in #{repo_name} (local only, no push)") do
              wc.remove(*orphans)
            end
          end
        end
      end

      def release_preflight
        Cimas::ReleasePreflight.new(self, runner: config["release_preflight_runner"]).run
      end

      def for_each
        sanity_check
        cmd = shell_cmd
        failures = []

        each_target_repo('for-each') do |repo, repo_dir|
          Dir.chdir(repo_dir) do
            puts "Execute '#{cmd}' for #{repo.name} repository..."
            system(cmd)
            unless $?.success?
              failures << repo.name
              puts "[ERROR] '#{cmd}' failed in #{repo.name} (exit #{$?.exitstatus})"
            end
          end
        end

        return if failures.empty?

        raise "[ERROR] for-each command failed in #{failures.size} repo(s): #{failures.join(', ')}"
      end

      private

      def required_option(key, flag)
        value = config[key]
        raise Cimas::Cli::Error, "Missing #{flag} value" if value.nil?

        value
      end

      # Coerces a CLI/cimas.yml value that may be a (comma-separated)
      # String, a bare value, or an Array into a flat list of strings.
      def string_list(value)
        Array(value).flat_map { |item| item.is_a?(String) ? item.split(',') : item }
      end

      # Deletes a remote branch, reporting the outcome with a uniform
      # [deleted]/[absent]/[ERROR] prefix; `reason` carries the
      # justification into the log lines.
      def delete_remote_branch(github_slug, branch, reason)
        dry_run("Delete branch #{github_slug}:#{branch} (#{reason})") do
          github_client.delete_branch(github_slug, branch)
          puts "[deleted] #{github_slug}:#{branch} (#{reason})"
        end
      rescue Octokit::UnprocessableEntity, Octokit::NotFound
        puts "[absent] #{github_slug}:#{branch} (#{reason}; branch already gone)"
      rescue Octokit::Error => e
        puts "[ERROR] #{github_slug}:#{branch} delete failed (#{e.class}): #{e.message}"
      end

      # Renders an ERB template from the config master against a repo's
      # binding context: legacy `template: binding:` values become
      # OpenStruct dot-notation methods (e.g. `<%= flavor %>`); the
      # `with:` block (metanorma/ci#300 Gap 1) is exposed as
      # `with_values` — a Hash — so templates can access keys that
      # aren't valid Ruby identifiers (e.g. `private-fonts`) via
      # `<%= with_values['private-fonts'] %>`. trim_mode '-' lets
      # templates trim conditional blocks without stray blank lines.
      def render_erb_template(source_path, repo)
        template = ERB.new(File.read(source_path), trim_mode: "-")
        params = OpenStruct.new(
          repo.binding.merge("with_values" => repo.with_values)
        ).instance_eval { binding }
        template.result(params)
      end

      def copy_file(from, to)
        write_managed(to, "copying file #{from} -> #{to}") do |out|
          File.foreach(from) do |line|
            out.puts line
          end
        end
      end

      def write_rendered(content, to)
        write_managed(to, "writing rendered template -> #{to}") do |out|
          out.puts content
        end
      end

      # One writer for every cimas-managed file: creates the target
      # directory, prefixes the generated header, then yields the file
      # handle for the body (copied lines or rendered template).
      def write_managed(to, description)
        dry_run(description) do
          to_dir = File.dirname(to)
          FileUtils.mkdir_p(to_dir) unless File.directory?(to_dir)

          File.open(to, 'w+') do |fo|
            fo.puts Cimas::GENERATED_HEADER
            yield fo
          end
        end
      end

      def dry_run(description, &block)
        if config['dry_run']
          puts "dry run: #{description}"
        else
          yield
        end
      end

      def groups
        data['groups'] || {}
      end

      def group_repo_names(group)
        case group
        when 'all'
          repositories.keys
        else
          if groups[group]
            groups[group]
          else
            [group] # if group is the repo by itself
          end
        end
      end
    end
  end
end
