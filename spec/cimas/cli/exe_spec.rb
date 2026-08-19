require "spec_helper"
require "open3"
require "tmpdir"
require "rbconfig"
require "fileutils"

# Boots the real executable in a subprocess — the only coverage for the
# Thor CLI layer in exe/cimas + Cimas::Cli::Runner (load-path setup,
# help, error UX, exit codes). A boot regression here is invisible to
# library specs.
RSpec.describe "exe/cimas" do
  let(:exe) { Cimas.root_path.join("exe/cimas").to_s }

  # Boot without bundler (clear RUBYOPT): the installed-gem execution
  # model. A require that only works under bundler is invisible here.
  CLEAN_ENV = { "RUBYOPT" => nil }.freeze

  def run_exe(*args)
    out, err, status = Open3.capture3(CLEAN_ENV, RbConfig.ruby, exe, *args)
    [out + err, status]
  end

  it "boots and prints help for a subcommand via the help subcommand" do
    out, status = run_exe("help", "push")

    expect(status.exitstatus).to eq(0)
    expect(out).to include("cimas push")
    expect(out).to include("--push-branch=BRANCH")
  end

  it "boots from a directory outside the repo (require_relative load)" do
    out, err, = Dir.mktmpdir("cimas-exe-spec") do |dir|
      Open3.capture3(CLEAN_ENV, RbConfig.ruby, exe, "diff", "-f", File.join(dir, "cimas.yml"), chdir: dir)
    end

    expect(out + err).to include("does not exist")
  end

  it "reports an unknown command cleanly (no backtrace) with exit 1" do
    out, status = run_exe("frobnicate")

    expect(status.exitstatus).to eq(1)
    expect(out).to include('Could not find command "frobnicate"')
    expect(out).not_to include("exe/cimas:") # backtrace lines carry file:line
  end

  it "guards a remote-mutating command without -g at the CLI level" do
    out, err, status = Dir.mktmpdir("cimas-exe-guard") do |dir|
      FileUtils.cp(Cimas.root_path.join("spec/fixtures/sample.yml"), File.join(dir, "cimas.yml"))
      Open3.capture3(CLEAN_ENV, RbConfig.ruby, exe, "push", "--dry-run", "-f", "cimas.yml", chdir: dir)
    end

    expect(status.exitstatus).to eq(1)
    expect(out + err).to include("no -g given")
  end

  it "accepts --dry-run after the sub-command name too" do
    out, err, status = Dir.mktmpdir("cimas-exe-dry") do |dir|
      FileUtils.cp(Cimas.root_path.join("spec/fixtures/sample.yml"), File.join(dir, "cimas.yml"))
      Open3.capture3(CLEAN_ENV, RbConfig.ruby, exe, "push", "--dry-run", "-f", "cimas.yml",
                     "-g", "metanorma", "-b", "b", "-m", "m", chdir: dir)
    end

    expect(status.exitstatus).to eq(0)
    expect(out + err).to include("Scope for push")
  end
end
