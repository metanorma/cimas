module Cimas
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
  class ReleasePreflight
    def initialize(command)
      @command = command
    end

    def run
      repo_name = @command.config['target_repo']

      repo = @command.repo_by_name(repo_name)
      if repo.nil?
        raise "[ERROR] #{repo_name} is not in cimas.yml. Run with --config-path pointing at the correct config."
      end

      repo_dir = File.join(@command.repos_path, repo_name)
      unless File.exist?(repo_dir) && File.exist?(File.join(repo_dir, '.git'))
        raise "[ERROR] #{repo_name} is not present in #{@command.repos_path}. Run `cimas setup` first."
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
        gem_spec = gemspec_file ? Gem::Specification.load(gemspec_file) : nil
        if gem_spec
          gem_name = gem_spec.name
          gem_version = gem_spec.version.to_s
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
  end
end
