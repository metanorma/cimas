require "thor"
require "pathname"

module Cimas
  module Cli
    # CLI surface only: declares options/help for each subcommand and
    # delegates to Cimas::Cli::Command (the orchestrator, where all
    # behavior lives). Adding a subcommand = one desc, its
    # method_option/shared_options block, and a one-line action calling
    # run_command. Shared flags are declared exactly once in
    # SHARED_OPTIONS.
    class Runner < Thor
      package_name "cimas"

      # Without this Thor 1.5 exits 0 on its own errors (unknown
      # command, bad options) — CI would read failure as success.
      def self.exit_on_failure?
        true
      end

      remove_command :tree

      class_option :verbose, type: :boolean, aliases: "-v",
                             desc: "Run verbosely"
      class_option :dry_run, type: :boolean,
                             desc: "Skip destructive/remote operations; print what would be done instead"

      SHARED_OPTIONS = {
        repos_path: { aliases: "-r", banner: "REPOS_PATH",
                      desc: "Repo root dir path" },
        config_path: { aliases: "-f", banner: "CONFIG_FILE_PATH",
                       desc: "Config file path" },
        master_path: { aliases: "-d", banner: "CONFIG_MASTER_DIR_PATH",
                       desc: "Config master path" },
        groups: { aliases: "-g", banner: "GROUP1,GROUP2",
                  desc: "Groups to update" },
        keep_changes: { aliases: "-k", type: :boolean,
                        desc: "Don't modify revert changes" },
      }.freeze

      # Thor option symbol → Command option key for value-carrying
      # flags; the distinct -b/-m spellings per command map onto the
      # command key the orchestrator reads.
      STRING_OPTION_KEYS = {
        push_branch: "push_to_branch",
        commit_message: "commit_message",
        merge_branch: "merge_branch",
        pr_message: "pr_message",
        pr_body: "pr_body",
        pr_body_file: "pr_body_file",
        assignees: "assignees",
        reviewers: "reviewers",
        shell_cmd: "shell_cmd",
        cleanup_branch: "push_to_branch",
        cleanup_branch_prefix: "cleanup_branch_prefix",
        orphan_branch: "push_to_branch",
        orphan_commit_message: "pr_message",
        cleanup_only_targets: "cleanup_only_targets",
        target_repo: "target_repo",
      }.freeze

      def self.shared_options(*names)
        names.each { |name| method_option name, SHARED_OPTIONS.fetch(name) }
      end

      desc "setup", "Clone all repos described in the config"
      shared_options :repos_path, :config_path
      def setup
        run_command("setup")
      end

      desc "pull", "Reset all repos to their configured branch and pull"
      shared_options :repos_path, :config_path, :groups
      def pull
        run_command("pull")
      end

      desc "sync", "Update CI configurations for all repos described in the config"
      shared_options :repos_path, :config_path, :master_path, :keep_changes, :groups
      def sync
        run_command("sync")
      end

      desc "diff", "Show diff for all repos"
      shared_options :repos_path, :config_path, :groups
      def diff
        run_command("diff")
      end

      desc "push", "Push changes to the remote server (requires -g)"
      shared_options :repos_path, :config_path, :keep_changes, :groups
      method_option :push_branch, aliases: "-b", banner: "BRANCH",
                                  desc: "Branch to push in all repos"
      method_option :commit_message, aliases: "-m", banner: "MESSAGE",
                                     desc: "Commit message"
      method_option :force_push, type: :boolean,
                                 desc: "Force push (with commit amend)"
      def push
        run_command("push")
      end

      desc "open-prs", "Open pull requests on GitHub (requires -g)"
      shared_options :repos_path, :config_path, :groups
      method_option :reviewers, aliases: "-w", banner: "REVIEWERS",
                                desc: "A comma-separated list (no spaces around the comma) of GitHub handles to request a review from"
      method_option :merge_branch, aliases: "-b", banner: "BRANCH",
                                   desc: "PR branch to merge into target"
      method_option :pr_message, aliases: "-m", banner: "MESSAGE",
                                 desc: "PR title (≤256 chars; what shows on the PR list page)"
      method_option :pr_body, banner: "BODY",
                              desc: "Inline PR body (markdown). Mutually exclusive with --body-file."
      method_option :pr_body_file, banner: "PATH",
                                   desc: "Path to a file whose contents become the PR body (markdown). Preferred for any non-trivial body — shell-escape-safe and version-controllable. Mutually exclusive with --body."
      method_option :assignees, aliases: "-a", banner: "ASSIGNMENTS",
                                desc: "A comma-separated list (no spaces around the comma) of GitHub handles to assign to this pull request."
      method_option :supersede_stale, type: :boolean,
                                      desc: "When opening a PR, detect any pre-existing open PRs on the same repo whose head branch starts with 'cimas-sync-' (i.e. previous wave PRs that never merged), label them 'superseded-by-#N' (where N is the new PR number), and post a comment linking the new PR. Does NOT auto-close the old PRs — the reviewer keeps authority over the close decision. The new PR's body is prepended with a 'Supersedes #X, #Y' line. See metanorma/ci#300 Gap 4."
      method_option :flatten_stale, type: :boolean,
                                    desc: "Gap 4 full: like --supersede-stale, but ALSO auto-closes the superseded PRs. Implies --supersede-stale. Use when confident the new wave's content strictly supersedes the older waves' (the standard cimas-sync-* case, since every wave regenerates the same files from cimas.yml). Superseded PRs get labelled 'superseded-closed-by-#N', a comment noting auto-closure, and are closed. See metanorma/ci#300 Gap 4 full."
      def open_prs
        run_command("open-prs")
      end

      desc "for-each", "Run a shell command for each repo (requires -g)"
      shared_options :repos_path, :config_path, :groups
      method_option :shell_cmd, aliases: "-c", banner: "SHELL_CMD",
                                desc: "Command to execute"
      def for_each
        run_command("for-each")
      end

      desc "cleanup-merged-prs", "Delete wave branches whose PR has merged (run after merges land; requires -g)"
      shared_options :repos_path, :config_path, :groups
      method_option :cleanup_branch, aliases: "-b", banner: "BRANCH",
                                     desc: "Wave branch to clean up (same as the -b push_to_branch used in `cimas push`)"
      def cleanup_merged_prs
        run_command("cleanup-merged-prs")
      end

      desc "cleanup-closed-prs", "Delete wave branches whose PR was closed without merge (org-wide sweep of cimas-sync-*; requires -g)"
      shared_options :repos_path, :config_path, :groups
      method_option :cleanup_branch_prefix, banner: "PREFIX",
                                            desc: "Branch-name prefix to sweep (default: cimas-sync-). All closed-not-merged PRs whose head.ref starts with this prefix have their remote branch deleted."
      def cleanup_closed_prs
        run_command("cleanup-closed-prs")
      end

      desc "cleanup-orphan-files", "Delete files with the Cimas auto-generated header that are no longer in cimas.yml mapping (sync's inverse; -g required with --push-after)"
      shared_options :repos_path, :config_path, :groups
      method_option :orphan_branch, aliases: "-b", banner: "BRANCH",
                                    desc: "Branch to create with the orphan-file deletions (e.g. cleanup-orphans-2026-07-05). Same shape as `-b` on push."
      method_option :orphan_commit_message, aliases: "-m", banner: "MESSAGE",
                                            desc: "Commit message for the cleanup commit."
      method_option :cleanup_push_after, type: :boolean,
                                         desc: "After detecting + staging orphan deletions, commit + force-push the cleanup branch to each repo's remote. Without this flag the deletions are staged locally only (for inspection / manual push)."
      method_option :cleanup_only_targets, banner: "PATH1,PATH2",
                                           desc: "Narrow the sweep to specific target paths (comma-separated, no spaces). Files at other target paths are left alone even if orphaned. Use to scope a cleanup wave to one class of orphan (e.g. --only-target=.github/workflows/generate.yml for the ci#347 docker-only cleanup)."
      def cleanup_orphan_files
        run_command("cleanup-orphan-files")
      end

      desc "release-preflight", "Local fail-fast checks before firing a release workflow"
      shared_options :repos_path, :config_path
      method_option :target_repo, banner: "NAME",
                                  desc: "Target gem repo to preflight (must be in cimas.yml)"
      def release_preflight
        run_command("release-preflight")
      end

      no_commands do
        def run_command(name)
          Cimas::Cli::Command.new(command_options).execute(name)
        end

        # Translates Thor's parsed options into the option hash
        # Cimas::Cli::Command consumes: string keys, Pathname paths,
        # comma-split groups. Keys absent here fall back to Command's
        # DEFAULT_CONFIG.
        def command_options
          opts = options

          result = path_options(opts)
          result.merge!(string_options(opts))
          result.merge!(flag_options(opts))
          result["groups"] = comma_list(opts[:groups]) if opts[:groups]
          if result["pr_body_file"]
            result["pr_body_file"] = existing_file(result["pr_body_file"], flag: "--body-file")
          end
          result
        end

        def path_options(opts)
          {
            "repos_path" => Pathname.getwd + (opts[:repos_path] || "repos"),
            "config_file_path" => existing_path(opts[:config_path] || "cimas.yml",
                                                flag: "-f/--config-path"),
            "config_master_path" => opts[:master_path] ? existing_path(opts[:master_path], flag: "-d/--master-path") : Pathname.getwd + "config",
            "dry_run" => opts[:dry_run] == true,
            "verbose" => opts[:verbose] == true,
          }
        end

        def string_options(opts)
          STRING_OPTION_KEYS.each_with_object({}) do |(thor_key, command_key), result|
            result[command_key] = opts[thor_key] unless opts[thor_key].nil?
          end
        end

        def flag_options(opts)
          result = {}
          %i[keep_changes force_push supersede_stale flatten_stale cleanup_push_after].each do |key|
            result[key.to_s] = true if opts[key]
          end
          # flatten implies supersede
          result["supersede_stale"] = true if result["flatten_stale"]
          result
        end

        def existing_path(value, flag:)
          path = Pathname.getwd + value
          raise Cimas::Cli::Error, "#{flag} path is not set or does not exist: #{path}" unless path.exist?

          path
        end

        def existing_file(value, flag:)
          file = Pathname.getwd + value
          raise Cimas::Cli::Error, "#{flag} path does not exist: #{file}" unless file.exist?

          file
        end

        def comma_list(value)
          value.split(",").map(&:strip).reject(&:empty?)
        end
      end
    end
  end
end
