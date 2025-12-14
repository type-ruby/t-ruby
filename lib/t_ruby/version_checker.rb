# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

module TRuby
  class VersionChecker
    GEM_NAME = "t-ruby"
    RUBYGEMS_API = "https://rubygems.org/api/v1/gems/#{GEM_NAME}.json".freeze

    def self.check
      new.check
    end

    def self.update
      new.update
    end

    def check
      latest = fetch_latest_version
      return nil unless latest

      current = Gem::Version.new(VERSION)
      latest_version = Gem::Version.new(latest)

      return nil if current >= latest_version

      { current: VERSION, latest: latest }
    end

    def update
      system("gem install #{GEM_NAME}")
    end

    private

    def fetch_latest_version
      uri = URI(RUBYGEMS_API)
      response = Net::HTTP.get_response(uri)

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data["version"]
    rescue StandardError
      nil
    end
  end
end
