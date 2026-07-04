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

    context "with a `template: binding:` block (legacy ERB binding)" do
      it "exposes the binding hash via `#binding`" do
        name = "mn-samples-plateau"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.binding).to eq("flavor" => "plateau")
      end
    end

    context "without a `template: binding:` block" do
      it "exposes an empty binding hash" do
        name = "metanorma-cli"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.binding).to eq({})
      end
    end

    context "with a `with:` block (metanorma/ci#300 Gap 1)" do
      it "exposes the with-block hash via `#with_values`" do
        name = "metanorma"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.with_values).to eq(
          "private-fonts" => true,
          "submodules" => true,
        )
      end

      it "keeps `#binding` empty when only `with:` is set" do
        name = "metanorma"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.binding).to eq({})
      end
    end

    context "without a `with:` block" do
      it "exposes an empty with-values hash" do
        name = "metanorma-cli"
        data = sample_data["repositories"][name]

        repository = Cimas::Repository.new(name, data)

        expect(repository.with_values).to eq({})
      end
    end
  end

  # End-to-end rendering — confirms the `with_values` hash reaches an ERB
  # template through the same binding shape `Cli::Command#sync` uses.
  # Mirrors the production render path in a spec-scale harness.
  describe "ERB rendering with `with_values`" do
    require "erb"
    require "ostruct"

    def render_with(repository, erb_source)
      erb_context = repository.binding.merge(
        "with_values" => repository.with_values,
      )
      params = OpenStruct.new(erb_context).instance_eval { binding }
      ERB.new(erb_source).result(params)
    end

    it "renders `with:` block values via hash access" do
      repository = Cimas::Repository.new(
        "metanorma",
        sample_data["repositories"]["metanorma"],
      )

      erb = <<~ERB
        with:
          private-fonts: <%= with_values['private-fonts'] %>
          submodules: <%= with_values['submodules'] %>
      ERB

      expect(render_with(repository, erb)).to eq(<<~YAML)
        with:
          private-fonts: true
          submodules: true
      YAML
    end

    it "preserves legacy `binding:` dot-notation access" do
      repository = Cimas::Repository.new(
        "mn-samples-plateau",
        sample_data["repositories"]["mn-samples-plateau"],
      )

      erb = "extra-flavors: <%= flavor %>\n"

      expect(render_with(repository, erb)).to eq("extra-flavors: plateau\n")
    end

    it "supports both mechanisms coexisting on one repo" do
      # Synthesised on the fly — not in the sample.yml fixture — to avoid
      # bloating the fixture with a case that only this spec cares about.
      data = {
        "remote" => "ssh://git@github.com/metanorma/hybrid",
        "branch" => "main",
        "files" => {},
        "template" => { "binding" => { "flavor" => "hybrid" } },
        "with" => { "private-fonts" => true },
      }
      repository = Cimas::Repository.new("hybrid", data)

      erb = <<~ERB
        flavor: <%= flavor %>
        private-fonts: <%= with_values['private-fonts'] %>
      ERB

      expect(render_with(repository, erb)).to eq(<<~YAML)
        flavor: hybrid
        private-fonts: true
      YAML
    end
  end

  def sample_data
    @sample_data ||= YAML.load_file(
      Cimas.root_path.join("spec/fixtures/sample.yml"),
    )
  end
end
