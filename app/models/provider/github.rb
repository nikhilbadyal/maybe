class Provider::Github
  attr_reader :name, :owner, :branch, :client

  def initialize(config = {})
    @name = config[:name] || ENV.fetch("GITHUB_REPO_NAME", "maybe")
    @owner = config[:owner] || ENV.fetch("GITHUB_REPO_OWNER", "maybe-finance")
    @branch = config[:branch] || ENV.fetch("GITHUB_REPO_BRANCH", "main")

    # Initialize the Octokit client with authentication
    @client = Octokit::Client.new(access_token: config[:token] || ENV["GITHUB_ACCESS_TOKEN"])
  end

  def fetch_latest_upgrade_candidates
    Rails.cache.fetch("latest_github_upgrade_candidates", expires_in: 30.minutes) do
      Rails.logger.info "Fetching latest GitHub upgrade candidates from #{repo} on branch #{branch}..."
      begin
        latest_release = client.releases(repo).first
        latest_version = latest_release ? Semver.from_release_tag(latest_release.tag_name) : Semver.new(Maybe.version)
        latest_commit = client.branch(repo, branch)

        release_info = if latest_release
          {
            version: latest_version,
            url: latest_release.html_url,
            commit_sha: client.commit(repo, latest_release.tag_name).sha
          }
        end

        commit_info = {
          version: latest_version,
          commit_sha: latest_commit.commit.sha,
          url: latest_commit.commit.html_url
        }

        {
          release: release_info,
          commit: commit_info
        }
      rescue => e
        Rails.logger.error "Failed to fetch latest GitHub commits: #{e.message}"
        nil
      end
    end
  end

  def fetch_latest_release_notes
    begin
      Rails.cache.fetch("latest_github_release_notes", expires_in: 2.hours) do
        release = client.releases(repo).first
        if release
          {
            avatar: release.author.avatar_url,
            # this is the username, it would be nice to get the full name
            username: release.author.login,
            name: release.name,
            published_at: release.published_at,
            body: client.markdown(release.body, mode: "gfm", context: repo)
          }
        else
          nil
        end
      end
    rescue => e
      Rails.logger.error "Failed to fetch latest GitHub release notes: #{e.message}"
      nil
    end
  end

  private
    def repo
      "#{owner}/#{name}"
    end
end
