require 'json'
require 'yaml'
require 'net/http'
require 'git'
require_relative '../repository'
require 'octokit'
require 'ostruct'

module Cimas
  module Cli
    class Command
      attr_accessor :github_client, :config

      DEFAULT_CONFIG = {
        'dry_run' => false,
        'verbose' => false,
        'groups' => ['all'],
        'force_push' => false,
        'assignees' => [],
        'reviewers' => [],
        'keep_changes' => false,
        'add_auto_merge_label' => true,
        'cooldown_count' => 10,
        'cooldown_time' => 3 * 60
      }

      def initialize(options)
        unless options['config_file_path'].exist?
          raise "[ERROR] config_file_path #{options['config_file_path']} does not exist, aborting."
        end

        @data = YAML.load(IO.read(options['config_file_path']))

        @config = DEFAULT_CONFIG.merge(settings || {}).merge(options)

        unless repos_path.exist?
          FileUtils.mkdir_p repos_path
        end

        if ENV["GITHUB_TOKEN"]
          @config['github_token'] ||= ENV["GITHUB_TOKEN"]
        end
      end

      def settings
        data['settings']
      end

      def github_client
        require 'octokit'
        if config['github_token'].nil?
          raise "[ERROR] Please set GITHUB_TOKEN environment variable to use GitHub functions."
        end
        @github_client ||= Octokit::Client.new(access_token: config['github_token'])
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
          # puts "attribs #{attribs.inspect}"
          unless File.exist?(repo_dir) && File.exist?(File.join(repo_dir, '.git'))
            puts "Git cloning #{repo_name} from #{attribs['remote']}..."
            Git.clone(attribs['remote'], repo_name, path: repos_path)
          else
            puts "Skip cloning #{repo_name}, #{repo_dir} already exists."
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

        warn "[ERROR] These repositories have not been setup, please run `setup` first: #{unsynced.inspect}"
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

        filtered_repo_names.each do |repo_name|

          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping sync for it."
            next
          end

          dry_run("Copying files to #{repo_name} and staging them") do
            g = Git.open(repo_dir)

            unless keep_changes
              g.checkout(repo.branch)
              g.reset_hard(repo.branch)
              g.clean(force: true)
            end

            puts "Syncing and staging files in #{repo_name}..."

            repo.files.each do |target, source|
              source_path = File.join(config_master_path, source)
              target_path = File.join(repos_path, repo_name, target)
              puts "file #{source_path} => #{target_path}" if verbose

              if source_path.end_with? ".erb"
                template = ERB.new(File.read(source_path))
                temp_file = Tempfile.new
                params = OpenStruct.new(repo.binding).instance_eval { binding }
                temp_file.puts(template.result(params))
                temp_file.flush
                copy_file(temp_file, target_path)
              else
                copy_file(source_path, target_path)
              end

              g.add(target)
            end

            apply_patches(repo_name, repo_dir, g)

            if verbose
              # Debugging to see if files have been changed
              g.status.changed.each do |file, status|
                puts "Updated files in #{repo_name}:"
                puts status.blob(:index).contents
              end
            end
          end
        end
      end

      def patches
        data['patches'] || {}
      end

      def apply_patches(repo_name, repo_dir, git)
        patches.each do |patch_name, patch|
          patch_groups = patch['groups'] || []
          target_repo_names = patch_groups.flat_map { |g| group_repo_names(g) }.uniq
          next unless target_repo_names.include?(repo_name)

          globs = Array(patch['files'])
          find_regex = Regexp.new(patch['find'])
          replacement = patch['replace']

          globs.each do |glob|
            matched = Dir.glob(File.join(repo_dir, glob))
            if matched.empty?
              puts "[WARNING] Patch '#{patch_name}' on #{repo_name}: no files matched glob '#{glob}'."
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
              #   - `find` matches but `gsub` produces identical text (the
              #     file is already at the target value). INFO-level: this is
              #     a normal idempotent no-op, not a problem.
              unless find_regex.match?(original)
                puts "[WARNING] Patch '#{patch_name}' on #{repo_name}:#{rel_path}: pattern not present in file (line absent — consider whether the patch should also handle insertion)."
                next
              end

              updated = original.gsub(find_regex, replacement)
              if original == updated
                puts "[INFO] Patch '#{patch_name}' on #{repo_name}:#{rel_path}: already at target value, no-op."
                next
              end

              dry_run("Patching #{rel_path} in #{repo_name} (patch '#{patch_name}')") do
                File.write(file_path, updated)
                git.add(rel_path)
              end
            end
          end
        end
      end

      def diff
        sanity_check

        filtered_repo_names.each do |repo_name|

          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping diff for it."
            next
          end

          g = Git.open(repo_dir)

          puts "======================= DIFF FOR #{repo_name} ========================="
          # Debugging to see if files have been changed
          diff = g.diff
          puts diff.patch
        end
      end

      def filtered_repo_names
        return repositories unless config['groups']

        config['groups'].inject([]) do |acc, group|
          acc + group_repo_names(group)
        end.uniq
      end

      def repo_by_name(name)
        Cimas::Repository.new(name, data["repositories"][name])
      end

      def pull
        sanity_check
        filtered_repo_names.each do |repo_name|

          repo = repo_by_name(repo_name)

          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts(
              "[ERROR] #{repo_name} is missing in #{repos_path}, " \
              " skipping pull for it."
            )

            next
          end

          g = Git.open(repo_dir)

          dry_run("Pulling from #{repo_name}/#{repo.branch}...") do
            puts "Pulling from #{repo_name}/#{repo.branch}..."
            g.remote("origin").fetch
            g.reset_hard(repo.branch) rescue 'ignore'
            g.checkout(repo.branch)
            g.pull("origin", repo.branch)
          end
        end

        puts "Done!"
      end

      def commit_message
        if config['commit_message'].nil?
          raise OptionParser::MissingArgument, "Missing -m/--message value"
        end
        msg = config['commit_message']
        unless msg.include? "request-checks:"
          # https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/about-status-checks#checks
          msg << "\n\nrequest-checks: true"
        end
        msg
      end

      def pr_message
        if config['pr_message'].nil?
          raise OptionParser::MissingArgument, "Missing -m/--message value"
        end
        config['pr_message']
      end

      def push_to_branch
        if config['push_to_branch'].nil?
          raise OptionParser::MissingArgument, "Missing -b/--push-branch value"
        end
        config['push_to_branch']
      end

      def merge_branch
        if config['merge_branch'].nil?
          raise OptionParser::MissingArgument, "Missing -b/--merge-branch value"
        end
        config['merge_branch']
      end

      def shell_cmd
        if config['shell_cmd'].nil?
          raise OptionParser::MissingArgument, "Missing -c/--shell-cmd value"
        end
        config['shell_cmd']
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

        filtered_repo_names.each do |repo_name|
          repo = repo_by_name(repo_name)

          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping push for it."
            next
          end

          g = Git.open(repo_dir)
          dry_run("Pushing branch #{push_to_branch} (commit #{g.object('HEAD').sha}) to #{g.remotes.first}:#{repo_name}") do
            puts "repo.branch #{repo.branch}"

            unless keep_changes
              g.checkout(repo.branch)
              g.reset(repo.branch)
              g.branch(push_to_branch).delete if g.is_branch?(push_to_branch)
            end
            g.branch(push_to_branch).checkout
            g.add(repo.files.keys)

            if g.status.changed.empty? &&
                g.status.added.empty? &&
                g.status.deleted.empty?

              puts "Skipping commit on #{repo_name}, no changes detected."
            else
              puts "Committing on #{repo_name}."
              g.commit_all(commit_message)#, amend: true)
            end

            # Still push even if there was no commit, as the remote branch
            # may have been deleted. If the remote branch is deleted we can't
            # make PRs in the next stage.
            begin
              if force_push
                puts "Force-pushing branch #{push_to_branch} (commit #{g.object('HEAD').sha}) to #{g.remotes.first}:#{repo_name}."
                g.push(g.remotes.first, push_to_branch, force: true)
              else
                puts "Pushing branch #{push_to_branch} (commit #{g.object('HEAD').sha}) to #{g.remotes.first}:#{repo_name}."
                g.push(g.remotes.first, push_to_branch)
              end
            rescue Git::GitExecuteError => ex
              case ex.message
              when /hint: Updates were rejected because the tip of your current branch is behind/
                puts "[WARNING] branch #{push_to_branch} already exists on remote. If you wanna force push, pass --force"
              else
                puts "An error of type #{ex.class} happened, message is #{ex.message}"
              end
            end
          end
        end

        # run_cmd("git -C #{repos_path} multi -c add appveyor.yml")
      end

      def git_remote_to_github_name(remote)
        remote.match(/github.com\/(.*)/)[1]
      end

      def open_prs
        sanity_check
        branch = merge_branch
        message = pr_message
        # Resolve PR body from --body-file (preferred), --body inline, or fall back
        # to the legacy "As title." placeholder. See metanorma/cimas#49 Bug 1: the
        # previous open-prs unconditionally used `-m` as the title and a hard-coded
        # body placeholder, so multi-line PR bodies were impossible — and passing a
        # long markdown body via `-m` made it the title, triggering HTTP 422
        # "title is too long (max 256 chars)" and aborting the whole open-prs loop.
        if options['pr_body_file'] && options['pr_body']
          raise OptionParser::InvalidArgument, "--body and --body-file are mutually exclusive"
        end
        body = if options['pr_body_file']
                 File.read(options['pr_body_file'])
               elsif options['pr_body']
                 options['pr_body']
               else
                 "As title. \n\n _Generated by Cimas_."
               end
        # Coerce to an Array of handles. Accepts:
        #   - Array of strings from cimas.yml settings (the legacy shape)
        #   - String from the `-a` / `-w` CLI flags (a single handle, OR a
        #     comma-separated list per the option's help text)
        # Without coercion, `-a opoudjis` reached this block as a bare String
        # and `.join(',')` further down crashed with NoMethodError, aborting
        # `cimas open-prs` before any PR could be created.
        assignees = Array(config['assignees']).flat_map { |x| x.is_a?(String) ? x.split(',') : x }
        reviewers = Array(config['reviewers']).flat_map { |x| x.is_a?(String) ? x.split(',') : x }
        cooldown_count = config['cooldown_count']
        cooldown_time = config['cooldown_time']

        cooldown_counter = 0

        filtered_repo_names.each do |repo_name|
          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping sync_and_commit for it."
            next
          end

          g = Git.open(repo_dir)
          github_slug = git_remote_to_github_name(repo.remote)

          # --supersede-stale: detect prior open cimas-sync-* PRs on this repo.
          # See metanorma/ci#300 Gap 4. Cheaper-version (no strict-superset
          # check): we label-and-comment-but-do-not-close the old PRs, letting
          # the reviewer keep authority over the close decision. The new PR's
          # body is prepended with a "Supersedes #X, #Y" note so the reviewer
          # sees the full picture in the most recent PR.
          stale_prs = []
          if options['supersede_stale']
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

              # Label-and-comment-but-don't-close the superseded PRs (Gap 4 cheaper).
              stale_prs.each do |stale|
                begin
                  github_client.add_labels_to_an_issue(github_slug, stale.number, ["superseded-by-##{number}"])
                  github_client.add_comment(
                    github_slug,
                    stale.number,
                    "Superseded by ##{number} from a later cimas-sync wave (`#{branch}`). " \
                    "This PR was **not auto-closed** by cimas — the reviewer keeps authority over the close decision. " \
                    "Close after merging ##{number}, or rebase this branch onto something else if part of its content should still be preserved. " \
                    "(metanorma/ci#300 Gap 4)"
                  )
                  puts "  superseded #{github_slug}\##{stale.number} (labelled + commented)"
                rescue Octokit::Error => e
                  puts "  [WARNING] could not label/comment supersede on #{github_slug}\##{stale.number}: #{e.message}"
                end
              end

              puts "PR #{github_slug}\##{number} created"

            rescue Octokit::Error => e
              # puts e.inspect
              # puts '------'
              # puts "e.message #{e.message}"

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

            # puts pr.inspect

            unless pr
              puts "[WARNING] Detecting PR from GitHub..."
              github_branch_owner = github_slug.match(/(.*)\/.*/)[1]
              prs = github_client.pull_requests(github_slug, head: "#{github_branch_owner}:#{branch}")
              pr = prs.first
              unless pr
                puts "[WARNING] Failed to detect PR from GitHub for #{github_slug} repo. Skipping."
                next 
              end
              puts "[WARNING] Detected PR to be #{github_slug}\##{pr['number']}, continue processing."
            end

            # TODO: Catch

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
                # puts e.inspect
                # puts '------'
                # puts "e.message #{e.message}"

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

        filtered_repo_names.each do |repo_name|
          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

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
            dry_run("Delete branch #{github_slug}:#{branch} (no PR found)") do
              begin
                github_client.delete_branch(github_slug, branch)
                puts "[deleted-no-pr] #{github_slug}:#{branch}"
              rescue Octokit::UnprocessableEntity, Octokit::NotFound
                puts "[absent] #{github_slug}:#{branch} (already deleted)"
              rescue Octokit::Error => e
                puts "[ERROR] #{github_slug}:#{branch} delete failed (#{e.class}): #{e.message}"
              end
            end
            next
          end

          if pr.merged_at
            dry_run("Delete branch #{github_slug}:#{branch} (PR ##{pr.number} merged)") do
              begin
                github_client.delete_branch(github_slug, branch)
                puts "[deleted-merged] #{github_slug}:#{branch} (PR ##{pr.number})"
              rescue Octokit::UnprocessableEntity, Octokit::NotFound
                puts "[absent] #{github_slug}:#{branch} (PR ##{pr.number} merged but branch already gone)"
              rescue Octokit::Error => e
                puts "[ERROR] #{github_slug}:#{branch} delete failed (#{e.class}): #{e.message}"
              end
            end
          elsif pr.state == 'open'
            puts "[skip-open] #{github_slug}:#{branch} (PR ##{pr.number} still open)"
          else
            # Closed-without-merge — keep branch by default; closing without merge
            # often means someone intends to revisit. Operator can clean up manually.
            puts "[skip-closed] #{github_slug}:#{branch} (PR ##{pr.number} closed without merge)"
          end
        end
      end

      # Local maintainer-side preflight that mirrors the GHA preflight job in
      # `metanorma/ci/.github/workflows/rubygems-release.yml`. Runs against a
      # single repo's workspace clone before the maintainer fires the
      # `workflow_dispatch` to actually start the release chain. Catches the
      # cheap, deterministic failure modes (bundle resolve, gemspec errors,
      # missing credentials, already-published version) in ~30 sec locally,
      # so the maintainer never commits to the 2+ hour chain on a release
      # that was going to fail.
      #
      # Companion to the GHA-side preflight introduced in metanorma/ci PR #313.
      # Both protect against the same class of failures; the GHA preflight
      # protects every release attempt automatically, this one protects the
      # maintainer who runs it before firing.
      def release_preflight
        repo_name = config['target_repo']
        if repo_name.nil? || repo_name.empty?
          raise OptionParser::MissingArgument, "Missing --repo <name>"
        end

        repo = repo_by_name(repo_name)
        if repo.nil?
          raise "[ERROR] #{repo_name} is not in cimas.yml. Run with --config-path pointing at the correct config."
        end

        repo_dir = File.join(repos_path, repo_name)
        unless File.exist?(repo_dir) && File.exist?(File.join(repo_dir, '.git'))
          raise "[ERROR] #{repo_name} is not present in #{repos_path}. Run `cimas setup` first."
        end

        puts "=== cimas release-preflight: #{repo_name} ==="
        puts "    workspace: #{repo_dir}"
        puts ""

        failures = []

        Dir.chdir(repo_dir) do
          puts "[1/4] Fresh bundle install (Gemfile.lock removed first)..."
          File.delete('Gemfile.lock') if File.exist?('Gemfile.lock')
          unless system('bundle install --jobs 4 --retry 3')
            failures << 'bundle install'
            puts "    ✗ bundle install failed"
          else
            puts "    ✓ bundle install succeeded"
          end
          puts ""

          puts "[2/4] Gem build (validates gemspec)..."
          gemspec_file = Dir['*.gemspec'].first
          if gemspec_file.nil?
            puts "    ⚠️  No .gemspec file found in repo root; skipping gem build check"
          else
            if system("gem build #{gemspec_file}")
              puts "    ✓ gem build succeeded"
              Dir['*.gem'].each { |f| File.delete(f) }
            else
              failures << 'gem build'
              puts "    ✗ gem build failed"
            end
          end
          puts ""

          puts "[3/4] Verify publish credentials available..."
          creds_path = File.expand_path('~/.gem/credentials')
          if File.exist?(creds_path)
            puts "    ✓ ~/.gem/credentials present (API-key publish path viable)"
          elsif ENV['RUBYGEMS_API_KEY'] && !ENV['RUBYGEMS_API_KEY'].empty?
            puts "    ✓ RUBYGEMS_API_KEY env var present"
          else
            puts "    ⚠️  No ~/.gem/credentials and no RUBYGEMS_API_KEY env var."
            puts "        OIDC Trusted Publishing may still work in CI, but local `gem push` will fail."
            puts "        Configure ~/.gem/credentials if you intend to publish from this machine."
          end
          puts ""

          puts "[4/4] Version awareness..."
          if gemspec_file
            gem_name = `ruby -e "puts Gem::Specification.load('#{gemspec_file}').name"`.strip
            gem_version = `ruby -e "puts Gem::Specification.load('#{gemspec_file}').version.to_s"`.strip
            remote_list = `gem list --remote --exact --version "#{gem_version}" "#{gem_name}" 2>/dev/null`
            if remote_list.include?("#{gem_name} (#{gem_version})")
              puts "    ℹ️  #{gem_name} #{gem_version} is already on rubygems.org"
              puts "        With next_version=skip, the idempotent guard will skip the actual gem push."
              puts "        If you intended to ship NEW code, fire with next_version=patch (or major/minor)."
            else
              puts "    ✓ #{gem_name} #{gem_version} is NOT yet on rubygems — clean to publish"
              latest_list = `gem list --remote --exact "#{gem_name}" 2>/dev/null`
              if latest_match = latest_list.match(/#{Regexp.escape(gem_name)} \(([0-9.]+)/)
                puts "        Latest published: #{gem_name} #{latest_match[1]}"
              else
                puts "        (No previous public version found.)"
              end
            end
          else
            puts "    (skipped — no gemspec to identify)"
          end
          puts ""
        end

        puts "=== Result ==="
        if failures.empty?
          puts "✓ All preflight checks passed for #{repo_name}."
          puts "  Safe to fire: gh workflow run release.yml --repo metanorma/#{repo_name} --field next_version=patch"
        else
          puts "✗ Preflight FAILED for #{repo_name}: #{failures.join(', ')}"
          puts "  Do NOT fire the release workflow until the failures above are fixed."
          exit 1
        end
      end

      def for_each
        sanity_check
        cmd = shell_cmd

        filtered_repo_names.each do |repo_name|
          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping sync for it."
            next
          end

          Dir.chdir(repo_dir) do
            puts "Execute '#{cmd}' for #{repo_name} repository..."
            system(cmd)
          end
        end
      end

      private

      def copy_file(from, to)
        dry_run("copying file #{from} -> #{to}") do
          to_dir = File.dirname(to)
          unless File.directory?(to_dir)
            FileUtils.mkdir_p(to_dir)
          end

          File.open(to, 'w+') do |fo|
            fo.puts '# Auto-generated by Cimas: Do not edit it manually!'
            fo.puts '# See https://github.com/metanorma/cimas'
            File.foreach(from) do |li|
              fo.puts li
            end
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
        data['groups']
      end

      def group_repo_names(group)
        # puts "group #{group}"
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

      def repo_sync(repo)
      end
    end
  end
end
