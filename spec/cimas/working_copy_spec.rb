require "spec_helper"
require "fileutils"
require "tmpdir"
require "git"

RSpec.describe Cimas::WorkingCopy do
  let(:root) { Dir.mktmpdir("cimas-wc-spec") }
  let(:origin) { File.join(root, "origin.git") }
  let(:clone_dir) { File.join(root, "repo") }

  after { FileUtils.rm_rf(root) }

  def commit_file(git, name, content, message)
    File.write(File.join(git.dir.to_s, name), content)
    git.add(name)
    git.commit(message)
  end

  def clone_repo(name = "repo")
    git = Git.clone(origin, name, path: root)
    git.config("user.name", "Spec")
    git.config("user.email", "spec@example.com")
    git
  end

  before do
    system("git", "init", "--bare", "--initial-branch", "main", origin,
           out: File::NULL, err: File::NULL)
    git = clone_repo
    commit_file(git, "README.md", "initial\n", "init")
    git.push("origin", "main")
  end

  let(:git_repo) { Git.open(clone_dir) }
  let(:wc) { described_class.new(git_repo) }

  describe "#drift?" do
    it "is false on a clean copy and true once a file changes" do
      expect(wc.drift?).to be(false)

      File.write(File.join(clone_dir, "Gemfile"), "source 'https://rubygems.org'")

      expect(wc.drift?).to be(true)
    end
  end

  describe "#reset_clean" do
    it "discards modifications and staged files, returning to the branch" do
      File.write(File.join(clone_dir, "README.md"), "dirty\n")
      File.write(File.join(clone_dir, "extra.txt"), "x")
      git_repo.add("extra.txt")

      wc.reset_clean("main")

      expect(File.read(File.join(clone_dir, "README.md"))).to eq("initial\n")
      expect(wc.drift?).to be(false)
    end
  end

  describe "#reset_onto and #switch_branch" do
    it "provisions a fresh wave branch, discarding a prior one" do
      commit_file(git_repo, "a.txt", "a\n", "on main")
      wc.reset_onto("main", discard_branch: "wave-1")
      wc.switch_branch("wave-1")
      commit_file(git_repo, "b.txt", "b\n", "wave work")

      wc.reset_onto("main", discard_branch: "wave-1")
      wc.switch_branch("wave-1")

      expect(File.exist?(File.join(clone_dir, "b.txt"))).to be(false)
    end

    it "switch_branch(fresh: true) discards an existing branch" do
      commit_file(git_repo, "a.txt", "a\n", "on main")
      wc.switch_branch("wave-1")
      commit_file(git_repo, "b.txt", "b\n", "wave work")

      wc.reset_onto("main")
      wc.switch_branch("wave-1", fresh: true)

      expect(File.exist?(File.join(clone_dir, "b.txt"))).to be(false)
    end
  end

  describe "staging and committing" do
    it "tracks staged state via clean? and commits via commit_all" do
      expect(wc.clean?).to be(true)

      wc.stage("README.md")
      File.write(File.join(clone_dir, "README.md"), "changed\n")
      git_repo.add("README.md")

      expect(wc.clean?).to be(false)

      wc.commit_all("a change")
      expect(wc.clean?).to be(true)
      expect(git_repo.log.first.message).to eq("a change")
    end
  end

  describe "#push" do
    it "returns :pushed and lands the branch on the remote" do
      wc.switch_branch("wave-1")
      commit_file(git_repo, "w.txt", "w\n", "wave")

      expect(wc.push("wave-1")).to eq(:pushed)
      expect(Git.bare(origin).is_branch?("wave-1")).to be(true)
    end

    it "returns :behind_remote when the remote tip moved, :pushed with force" do
      wc.switch_branch("wave-1")
      commit_file(git_repo, "w.txt", "w\n", "wave")
      wc.push("wave-1")

      other = clone_repo("other")
      other.checkout("wave-1")
      commit_file(other, "x.txt", "x\n", "remote moves on")
      other.push("origin", "wave-1")

      commit_file(git_repo, "y.txt", "y\n", "divergent local work")

      expect(wc.push("wave-1")).to eq(:behind_remote)
      expect(wc.push("wave-1", force: true)).to eq(:pushed)
    end
  end

  describe "readers" do
    it "exposes head_sha, remote_name, and diff_patch" do
      expect(wc.head_sha).to eq(git_repo.log.first.sha)
      expect(wc.remote_name).to eq("origin")

      File.write(File.join(clone_dir, "README.md"), "changed\n")

      expect(wc.diff_patch).to include("-initial")
      expect(wc.diff_patch).to include("+changed")
    end
  end
end
