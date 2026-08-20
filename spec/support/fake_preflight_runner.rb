# Controllable process boundary for ReleasePreflight offline specs.
class FakePreflightRunner
  attr_reader :system_commands, :captures

  def initialize(system_results: {}, captures: {}, credentials: false, api_key: false)
    @system_results = system_results
    @captures = captures
    @credentials = credentials
    @api_key = api_key
    @system_commands = []
  end

  def system!(cmd)
    @system_commands << cmd
    @system_results.fetch(cmd) { @system_results.fetch(:default, true) }
  end

  def capture(cmd)
    @captures.fetch(cmd) { @captures.fetch(:default, "") }
  end

  def credentials_present?
    @credentials
  end

  def api_key_present?
    @api_key
  end
end
