require "spec_helper"

RSpec.describe Cimas::Repository do
  describe ".new" do
    context "with valid repository hash" do
      it "initialize repository with attributes" do
        name = "metanorma-cli"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.name).to eq(name)
        expect(repository.files.count).to eq(3)
        expect(repository.branch).to eq("master")
        expect(repository.remote).to include("/metanorma/metanorma-cli")
      end
    end

    context "with invalid repository hash" do
      it "does not set any attributes and returns to to nil?" do
        name = "invalid-repo-name"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository).to be_nil
        expect(repository.nil?).to be_truthy
      end
    end
  end

  def sample_data
    @sample_data ||= YAML.load_file(
      Cimas.root_path.join("spec/fixtures/sample.yml"),
    )
  end
end
