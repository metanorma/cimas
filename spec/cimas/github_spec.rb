require "spec_helper"

RSpec.describe Cimas::GitHub do
  describe "#slug_for" do
    subject(:github) { described_class.new(token: "t") }

    it "maps the three common remote forms and strips .git" do
      expect(github.slug_for("ssh://git@github.com/org/repo")).to eq("org/repo")
      expect(github.slug_for("git@github.com:org/repo.git")).to eq("org/repo")
      expect(github.slug_for("https://github.com/org/repo.git")).to eq("org/repo")
    end

    it "rejects non-GitHub remotes" do
      expect { github.slug_for("git@gitlab.com:org/repo.git") }
        .to raise_error(/not a GitHub remote/)
    end
  end

  describe "#client" do
    it "requires a token when no client is injected" do
      expect { described_class.new.client }
        .to raise_error(/GITHUB_TOKEN/)
    end

    it "returns an injected client without needing a token" do
      fake = FakeGitHubClient.new
      expect(described_class.new(client: fake).client).to equal(fake)
    end
  end

  describe "#fetch_visibility" do
    it "returns the private flag from the client" do
      fake = FakeGitHubClient.new
      fake.repo_private_by_slug["org/private"] = true
      github = described_class.new(client: fake)

      expect(github.fetch_visibility("org/private")).to be(true)
      expect(github.fetch_visibility("org/public")).to be(false)
    end

    it "defaults to private on NotFound" do
      fake = Object.new
      def fake.repo(_slug)
        raise Octokit::NotFound
      end
      github = described_class.new(client: fake)

      expect { expect(github.fetch_visibility("org/x")).to be(true) }
        .to output(/defaulting to `private`/).to_stdout
    end
  end
end
