require 'json'
require 'yaml'
require 'net/http'
require 'git'
require_relative '../repository'
require 'octokit'
# require 'travis/client/session'

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

        @config = DEFAULT_CONFIG.merge(settings).merge(options)

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
                p "repo.binding=#{repo.binding}"
                params = OpenStruct.new(repo.binding).instance_eval { binding }
                temp_file.puts(template.result(params))
                temp_file.flush
                copy_file(temp_file, target_path)
              else
                copy_file(source_path, target_path)
              end

              g.add(target)
            end

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
        config['commit_message']
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

        # do two separate `git add` because one of it may be missing
        # run_cmd("git -C #{repos_path} multi -c add .travis.yml", dry_run)
        # run_cmd("git -C #{repos_path} multi -c add appveyor.yml")
      end

      def git_remote_to_github_name(remote)
        remote.match(/github.com\/(.*)/)[1]
      end

      def open_prs
        sanity_check
        branch = merge_branch
        message = pr_message
        assignees = config['assignees']
        reviewers = config['reviewers']
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

          dry_run("Opening GitHub PR: #{github_slug}, branch #{repo.branch} <- #{branch}, message '#{message}'") do
            puts "Opening GitHub PR: #{github_slug}, branch #{repo.branch} <- #{branch}, message '#{message}'"

            begin
              pr = github_client.create_pull_request(
                github_slug,
                repo.branch,
                branch,
                message,
                "As title. \n\n _Generated by Cimas_."
              )
              number = pr['number']

              github_client.add_labels_to_an_issue(github_slug, number, ['automerge']) if add_auto_merge_label

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
