# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "openssl"

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

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_callback = ->(_preverify_ok, _store_ctx) { true } # Skip CRL check
      http.open_timeout = 3
      http.read_timeout = 3

      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data["version"]
    rescue StandardError
      nil
    end
  end
end
