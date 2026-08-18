require "spec_helper"

RSpec.describe Cimas::Cli::Runner do
  describe "#command_options" do
    def options_for(extra = {})
      defaults = { config_path: "spec/fixtures/sample.yml" }
      described_class.new([], defaults.merge(extra), {}).command_options
    end

    it "splits comma-separated groups into a clean list" do
      expect(options_for(groups: "data, model")["groups"]).to eq(%w[data model])
    end

    it "maps -b variants onto push_to_branch" do
      expect(options_for(push_branch: "wave")["push_to_branch"]).to eq("wave")
      expect(options_for(cleanup_branch: "b")["push_to_branch"]).to eq("b")
      expect(options_for(orphan_branch: "b2")["push_to_branch"]).to eq("b2")
    end

    it "maps -m variants onto their respective command keys" do
      expect(options_for(commit_message: "m")["commit_message"]).to eq("m")
      expect(options_for(pr_message: "t")["pr_message"]).to eq("t")
      expect(options_for(orphan_commit_message: "m2")["pr_message"]).to eq("m2")
    end

    it "makes --flatten-stale imply --supersede-stale" do
      result = options_for(flatten_stale: true)

      expect(result["flatten_stale"]).to be(true)
      expect(result["supersede_stale"]).to be(true)
    end

    it "defaults dry_run/verbose false and yields Pathname paths" do
      result = options_for({})

      expect(result["dry_run"]).to be(false)
      expect(result["verbose"]).to be(false)
      expect(result["repos_path"]).to be_a(Pathname)
      expect(result["config_file_path"]).to be_a(Pathname)
    end

    it "rejects a --body-file that does not exist" do
      expect { options_for(pr_body_file: "no-such-body.md") }
        .to raise_error(Cimas::Cli::Error, /--body-file path does not exist/)
    end
  end
end
