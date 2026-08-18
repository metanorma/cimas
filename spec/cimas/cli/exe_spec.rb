require "spec_helper"
require "open3"
require "rbconfig"
require "fileutils"

# Boots the real executable in a subprocess — the only coverage for the
# option-parsing/dispatch layer in exe/cimas (load-path setup, registrar
# table, error UX). A boot regression here is invisible to library specs.
RSpec.describe "exe/cimas" do
  let(:exe) { Cimas.root_path.join("exe/cimas").to_s }

  def run_exe(*args)
    out, err, status = Open3.capture3(RbConfig.ruby, exe, *args)
    [out + err, status]
  end

  it "boots and prints help for a subcommand" do
    out, status = run_exe("push", "--help")

    expect(status.exitstatus).to eq(0)
    expect(out).to include("Usage: cimas push [options]")
    expect(out).to include("--push-branch=BRANCH")
  end

  it "boots from a directory outside the repo (load-path setup)" do
    out, status = Dir.mktmpdir("cimas-exe-spec") do |dir|
      Open3.capture3(RbConfig.ruby, exe, "diff", "-f", File.join(dir, "cimas.yml"), chdir: dir)
    end

    expect(out).to include("does not exist")
  end

  it "reports a user error cleanly (no backtrace) with exit 1" do
    out, status = run_exe("frobnicate")

    expect(status.exitstatus).to eq(1)
    expect(out).to include("unknown subcommand: frobnicate")
    expect(out).not_to include("exe/cimas:") # backtrace lines carry file:line
  end

  it "guards a remote-mutating command without -g at the CLI level" do
    out, _err, status = Dir.mktmpdir("cimas-exe-guard") do |dir|
      FileUtils.cp(Cimas.root_path.join("spec/fixtures/sample.yml"), File.join(dir, "cimas.yml"))
      Open3.capture3(RbConfig.ruby, exe, "--dry-run", "push", "-f", "cimas.yml", chdir: dir)
    end

    expect(status.exitstatus).to eq(1)
    expect(out).to include("no -g given")
  end
end
