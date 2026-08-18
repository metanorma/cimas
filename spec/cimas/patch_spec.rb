require "spec_helper"

RSpec.describe Cimas::Patch do
  let(:attrs) do
    {
      "files" => ["*.gemspec"],
      "find" => 'spec\.required_ruby_version\s*=.*',
      "replace" => 'spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")',
      "groups" => ["processor", "model"],
    }
  end

  it "exposes the config entry as typed attributes" do
    patch = described_class.new("ruby_version", attrs)

    expect(patch.name).to eq("ruby_version")
    expect(patch.globs).to eq(["*.gemspec"])
    expect(patch.group_names).to eq(%w[processor model])
    expect(patch.replacement)
      .to eq('spec.required_ruby_version = Gem::Requirement.new(">= 3.1.0")')
  end

  it "compiles the find pattern once at construction" do
    patch = described_class.new("ruby_version", attrs)

    expect(patch.find_regexp).to be_a(Regexp)
    expect(patch.find_regexp).to equal(patch.find_regexp)
  end

  it "defaults groups to an empty list when omitted" do
    patch = described_class.new("bare", { "files" => ["x"], "find" => "a", "replace" => "b" })

    expect(patch.group_names).to eq([])
  end

  it "normalizes a single-file string to a one-element glob list" do
    patch = described_class.new("s", { "files" => "x.yml", "find" => "a", "replace" => "b" })

    expect(patch.globs).to eq(["x.yml"])
  end

  describe "#matches?" do
    it "is true when the find pattern occurs in the content" do
      patch = described_class.new("ruby_version", attrs)

      expect(patch.matches?('  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")')).to be(true)
    end

    it "is false when the pattern is absent" do
      patch = described_class.new("ruby_version", attrs)

      expect(patch.matches?("spec.name = 'foo'")).to be(false)
    end
  end

  describe "#apply" do
    it "replaces matching content and supports backreferences" do
      patch = described_class.new("ver", { "files" => ["x"], "find" => 'version (\d+)', "replace" => 'version 9.\1' })

      expect(patch.apply("gem version 1")).to eq("gem version 9.1")
    end
  end
end
