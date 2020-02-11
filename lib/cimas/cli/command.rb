require 'json'
require 'yaml'
require 'net/http'
require 'git'
# require 'travis/client/session'

module Cimas
  module Cli
    class Command
      attr_accessor :github_client, :config

      DEFAULT_CONFIG = {
        'dry_run' => false,
        'verbose' => false,
        'groups' => ['all'],
        'pull_branch' => 'master',
        'force_push' => false,
        'assignees' => [],
        'reviewers' => []
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
            puts "Skip cloning #{repo_name}, already exists."
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

        raise "[ERROR] These repositories have not been setup, please run `setup` first: #{unsynced.inspect}"
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

          branch = repo['branch']
          files = repo['files']

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping sync for it."
            next
          end

          dry_run("Copying files to #{repo_name} and staging them") do
            g = Git.open(repo_dir)
            g.checkout(branch)
            g.reset_hard(branch)
            g.clean(force: true)

            puts "Syncing and staging files in #{repo_name}..."

            files.each do |target, source|
              # puts "file #{source} => #{target}"
              source_path = File.join(config_master_path, source)
              target_path = File.join(repos_path, repo_name, target)
              # puts "file #{source_path} => #{target_path}"

              copy_file(source_path, target_path)
              g.add(target_path)
            end

            # Debugging to see if files have been changed
            # g.status.changed.each do |file, status|
            #   puts "Updated files in #{repo_name}:"
            #   puts status.blob(:index).contents
            # end
          end
        end
      end

      def diff
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

          branch = repo['branch']
          files = repo['files']

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping diff for it."
            next
          end

          g = Git.open(repo_dir)
          # g.checkout(branch)
          # g.reset_hard(branch)
          # g.clean(force: true)

          # puts "Syncing files in #{repo_name}..."
          #
          # files.each do |target, source|
          #   # puts "file #{source} => #{target}"
          #   source_path = File.join(config_master_path, source)
          #   target_path = File.join(repos_path, repo_name, target)
          #   # puts "file #{source_path} => #{target_path}"
          #
          #   copy_file(source_path, target_path)
          #   # g.add(target_path)
          # end

          puts "======================= DIFF FOR #{repo_name} ========================="
          # Debugging to see if files have been changed
          diff = g.diff
          puts diff.patch

          # g.status.changed.each do |file, status|
         #    puts "Updated files in #{repo_name}:"
         #    puts status.blob(:index).contents
         #  end
        end
      end

      # def lint(options)
      #   config_master_path = options['config_master_path']
      #   appveyor_token = options['appveyor_token']
      #
      #   config = YAML.load_file(File.join(config_master_path, 'ci.yml'))
      #
      #   validated = []
      #
      #   config['repos'].each do |_, repo_ci|
      #     travisci, appveyor = repo_ci.values_at('.travis.yml', 'appveyor.yml')
      #
      #     if travisci && !validated.include?(travisci)
      #       valid = system("travis lint #{File.join(config_master_path, travisci)}", :out => :close)
      #       puts "#{travisci} valid: #{valid}"
      #       validated << travisci
      #     end
      #
      #     if appveyor && !validated.include?(appveyor)
      #       uri = URI('https://ci.appveyor.com/api/projects/validate-yaml')
      #       http = Net::HTTP.new(uri.host, uri.port)
      #       http.use_ssl = true
      #
      #       req = Net::HTTP::Post.new(uri.path, {
      #         "Content-Type" => "application/json",
      #         "Authorization" => "Bearer #{appveyor_token}"
      #       })
      #       req.body = File.read(File.join(config_master_path, appveyor))
      #
      #       valid = http.request(req).kind_of? Net::HTTPSuccess
      #
      #       puts "#{appveyor} valid: #{valid}"
      #       validated << appveyor
      #     end
      #   end
      # end

      def filtered_repo_names
        return repositories unless config['groups']

        # puts "config['groups'] #{config['groups'].inspect}"
        config['groups'].inject([]) do |acc, group|
          acc + group_repo_names(group)
        end.uniq
      end

      def repo_by_name(name)
        # puts "getting repository for #{name}"
        data['repositories'][name]
      end

      def pull
        sanity_check
        filtered_repo_names.each do |repo_name|

          repo = repo_by_name(repo_name)
          if repo.nil?
            puts "[WARNING] #{repo_name} not configured, skipping."
            next
          end

          branch = repo['branch']
          files = repo['files']

          repo_dir = File.join(repos_path, repo_name)
          unless File.exist?(repo_dir)
            puts "[ERROR] #{repo_name} is missing in #{repos_path}, skipping pull for it."
            next
          end

          g = Git.open(repo_dir)

          dry_run("Pulling from #{repo_name}...") do
            puts "Pulling from #{repo_name}..."
            g.reset_hard(branch)
            g.checkout(branch)
            g.pull
            # g.fetch(g.remotes.first)
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


      def force_push
        config['force_push']
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
          # g.reset_hard(attribs['branch'])

          dry_run("Pushing branch #{push_to_branch} (commit #{g.object('HEAD').sha}) to #{g.remotes.first}:#{repo_name}") do
            g.branch(push_to_branch).checkout
            g.add(all: true)

            if g.status.changed.empty?
              puts "Skipping commit on #{repo_name}, no changes detected."
            else
              g.commit_all(commit_message)
            end

            if force_push
              # TODO implement
              raise "[ERROR] Force pushing with commit amend is not yet implemented."
            else
              puts "Pushing branch #{push_to_branch} (commit #{g.object('HEAD').sha}) to #{g.remotes.first}:#{repo_name}"
              g.push(g.remotes.first, push_to_branch)
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
          github_slug = git_remote_to_github_name(repo['remote'])

          dry_run("Opening GitHub PR: #{github_slug}, branch #{repo['branch']} <- #{branch}, message '#{message}'") do
            puts "Opening GitHub PR: #{github_slug}, branch #{repo['branch']} <- #{branch}, message '#{message}'"

            begin
              pr = github_client.create_pull_request(
                github_slug,
                repo['branch'],
                branch,
                message,
                "As title. \n\n _Generated by Cimas_."
              )
              number = pr['number']
              puts "PR #{github_slug}\##{number} created"

            rescue Octokit::Error => e
              # puts e.inspect
              # puts '------'
              # puts "e.message #{e.message}"

              case e.message
              when /A pull request already exists/
                puts "[WARNING] PR already exists for #{branch}."

              when /field: head\s+code: invalid/
                puts "[WARNING] Branch #{branch} does not exist on #{github_slug}. Did you run `push`? Skipping."
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
          # puts "groups #{groups.inspect}"
          groups[group]
        end
      end

    end
  end
end
