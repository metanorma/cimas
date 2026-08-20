require "octokit"

# Real stand-in for Octokit::Client — records calls and serves canned
# responses. Specs never use double()/allow/receive.
class FakeGitHubClient
  # Octokit-compatible error with a controllable message.
  class Error < Octokit::Error
    def initialize(message)
      @message = message
      super()
    end

    def message
      @message
    end
  end

  Head = Struct.new(:ref, keyword_init: true)
  PullRequest = Struct.new(:number, :head, :state, :merged_at, :closed_at, keyword_init: true) do
    def [](key)
      public_send(key.to_s == "number" ? :number : key)
    end
  end
  User = Struct.new(:login, keyword_init: true)
  Repo = Struct.new(:private, keyword_init: true)

  attr_reader :calls
  attr_accessor :user_login, :create_error, :repo_private_by_slug

  def initialize
    @calls = []
    @user_login = "bot-user"
    @pull_requests = Hash.new { |h, k| h[k] = [] }
    @next_pr_number = 10
    @create_error = nil
    @repo_private_by_slug = Hash.new(false)
    @deleted_branches = []
  end

  def seed_pull_request(slug, **attrs)
    defaults = {
      number: (@next_pr_number += 1),
      head: Head.new(ref: "cimas-sync-old"),
      state: "open",
      merged_at: nil,
      closed_at: nil,
    }
    pr = PullRequest.new(**defaults.merge(attrs))
    @pull_requests[slug] << pr
    pr
  end

  def user
    record(:user)
    User.new(login: @user_login)
  end

  def repo(slug)
    record(:repo, slug)
    Repo.new(private: @repo_private_by_slug[slug])
  end

  def pull_requests(slug, **opts)
    record(:pull_requests, slug, opts)
    list = @pull_requests[slug]
    if opts[:state] == "open"
      list.select { |p| p.state == "open" }
    elsif opts[:state] == "closed"
      list.select { |p| p.state == "closed" }
    elsif opts[:state] == "all"
      list
    else
      list
    end.then do |filtered|
      if opts[:head]
        filtered.select { |p| "#{slug.split('/').first}:#{p.head.ref}" == opts[:head] || p.head.ref == opts[:head].split(":", 2).last }
      else
        filtered
      end
    end
  end

  def create_pull_request(slug, base, head, title, body)
    record(:create_pull_request, slug, base, head, title, body)
    raise @create_error if @create_error

    number = (@next_pr_number += 1)
    pr = PullRequest.new(
      number: number,
      head: Head.new(ref: head),
      state: "open",
      merged_at: nil,
      closed_at: nil,
    )
    @pull_requests[slug] << pr
    { "number" => number }
  end

  def add_labels_to_an_issue(slug, number, labels)
    record(:add_labels_to_an_issue, slug, number, labels)
  end

  def add_comment(slug, number, body)
    record(:add_comment, slug, number, body)
  end

  def close_pull_request(slug, number)
    record(:close_pull_request, slug, number)
    pr = @pull_requests[slug].find { |p| p.number == number }
    pr.state = "closed" if pr
  end

  def request_pull_request_review(slug, number, reviewers:)
    record(:request_pull_request_review, slug, number, reviewers)
  end

  def add_assignees(slug, number, assignees)
    record(:add_assignees, slug, number, assignees)
  end

  def delete_branch(slug, branch)
    record(:delete_branch, slug, branch)
    @deleted_branches << [slug, branch]
  end

  def deleted_branches
    @deleted_branches
  end

  def calls_named(name)
    @calls.select { |c| c.first == name }
  end

  private

  def record(name, *args)
    @calls << [name, *args]
  end
end
