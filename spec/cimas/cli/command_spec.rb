require "spec_helper"

RSpec.describe Cimas::Repository do
  context "commit message must include request-checks" do
    it "add request-checks: true if missing" do
      command = Cimas::Cli::Command.new(options("Some commit message"))

      expect(command.commit_message).equal? "Some commit message\n\nrequest-checks: true"
    end

    it "don't modify message if request-checks: is passed" do
      command = Cimas::Cli::Command.new(options("Some commit message\n\nrequest-checks: false"))

      expect(command.commit_message).equal? "Some commit message\n\nrequest-checks: false"
    end
  end

  def config_file_path
    Cimas.root_path.join("spec/fixtures/sample.yml")
  end

  def options(commit_message)
    {
      'config_file_path' => config_file_path,
      'repos_path' => Pathname.new(Dir.tmpdir),
      'commit_message' => commit_message,
    }
  end
end
