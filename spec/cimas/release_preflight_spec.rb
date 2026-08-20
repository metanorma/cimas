require "spec_helper"
require "fileutils"
require "tmpdir"
require "yaml"
require "git"

RSpec.describe Cimas::ReleasePreflight do
  let(:root) { Dir.mktmpdir("cimas-preflight-spec") }
  let(:repos_path) { File.join(root, "repos") }
  let(:repo_dir) { File.join(repos_path, "sample-gem") }

  before do
    FileUtils.mkdir_p(repo_dir)
    git = Git.init(repo_dir)
    git.config("user.name", "Spec")
    git.config("user.email", "spec@example.com")
    File.write(File.join(repo_dir, "sample-gem.gemspec"), <<~GEMSPEC)
      Gem::Specification.new do |s|
        s.name = "sample-gem"
        s.version = "1.2.3"
        s.authors = ["Spec"]
        s.files = []
        s.summary = "spec"
      end
    GEMSPEC
    git.add("sample-gem.gemspec")
    git.commit("init")

    File.write(File.join(root, "cimas.yml"), YAML.dump(
      "repositories" => {
        "sample-gem" => {
          "remote" => "ssh://git@github.com/org/sample-gem",
          "branch" => "main",
          "files" => {},
        },
      },
    ))
  end

  after { FileUtils.rm_rf(root) }

  def command(runner:)
    Cimas::Cli::Command.new(
      "config_file_path" => Pathname.new(File.join(root, "cimas.yml")),
      "repos_path" => Pathname.new(repos_path),
      "target_repo" => "sample-gem",
      "release_preflight_runner" => runner,
    )
  end

  it "passes when bundle and gem build succeed and the version is unpublished" do
    runner = FakePreflightRunner.new(
      system_results: { default: true },
      captures: { default: "" },
      credentials: true,
    )

    expect { command(runner: runner).execute("release-preflight") }
      .to output(/All preflight checks passed for sample-gem/).to_stdout

    expect(runner.system_commands).to include(
      "bundle install --jobs 4 --retry 3",
      "gem build sample-gem.gemspec",
    )
  end

  it "fails when bundle install fails" do
    runner = FakePreflightRunner.new(
      system_results: {
        "bundle install --jobs 4 --retry 3" => false,
        "gem build sample-gem.gemspec" => true,
      },
      captures: { default: "" },
    )

    expect { command(runner: runner).execute("release-preflight") }
      .to output(/Preflight FAILED for sample-gem: bundle install/).to_stdout
      .and raise_error(SystemExit)
  end

  it "reports when the version is already on rubygems" do
    runner = FakePreflightRunner.new(
      system_results: { default: true },
      captures: {
        default: "sample-gem (1.2.3)\n",
      },
      api_key: true,
    )

    expect { command(runner: runner).execute("release-preflight") }
      .to output(/sample-gem 1\.2\.3 is already on rubygems\.org/).to_stdout
  end

  it "rejects a repo name not in cimas.yml" do
    runner = FakePreflightRunner.new
    cmd = Cimas::Cli::Command.new(
      "config_file_path" => Pathname.new(File.join(root, "cimas.yml")),
      "repos_path" => Pathname.new(repos_path),
      "target_repo" => "missing-gem",
      "release_preflight_runner" => runner,
    )

    expect { cmd.execute("release-preflight") }
      .to raise_error(/missing-gem is not in cimas.yml/)
  end
end
