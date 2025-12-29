# frozen_string_literal: true

require "spec_helper"

describe TRuby::VersionChecker do
  describe "GEM_NAME" do
    it "is t-ruby" do
      expect(described_class::GEM_NAME).to eq("t-ruby")
    end
  end

  describe "RUBYGEMS_API" do
    it "points to rubygems.org" do
      expect(described_class::RUBYGEMS_API).to include("rubygems.org")
      expect(described_class::RUBYGEMS_API).to include("t-ruby")
    end
  end

  describe ".check" do
    it "creates instance and calls check" do
      instance = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:check).and_return(nil)

      described_class.check

      expect(instance).to have_received(:check)
    end
  end

  describe ".update" do
    it "creates instance and calls update" do
      instance = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(instance)
      allow(instance).to receive(:update).and_return(true)

      described_class.update

      expect(instance).to have_received(:update)
    end
  end

  describe "#check" do
    let(:checker) { described_class.new }

    context "when latest version is higher" do
      before do
        allow(checker).to receive(:fetch_latest_version).and_return("999.0.0")
      end

      it "returns hash with current and latest versions" do
        result = checker.check
        expect(result).to be_a(Hash)
        expect(result).to have_key(:current)
        expect(result).to have_key(:latest)
        expect(result[:latest]).to eq("999.0.0")
      end
    end

    context "when current version is up to date" do
      before do
        allow(checker).to receive(:fetch_latest_version).and_return(TRuby::VERSION)
      end

      it "returns nil" do
        result = checker.check
        expect(result).to be_nil
      end
    end

    context "when fetch fails" do
      before do
        allow(checker).to receive(:fetch_latest_version).and_return(nil)
      end

      it "returns nil" do
        result = checker.check
        expect(result).to be_nil
      end
    end
  end

  describe "#update" do
    let(:checker) { described_class.new }

    it "runs gem install command" do
      allow(checker).to receive(:system).with("gem install t-ruby").and_return(true)

      result = checker.update

      expect(checker).to have_received(:system).with("gem install t-ruby")
      expect(result).to be true
    end
  end

  describe "#fetch_latest_version (private)" do
    let(:checker) { described_class.new }

    context "when API returns success" do
      it "parses version from JSON response" do
        response_body = '{"version": "1.2.3"}'
        response = instance_double(Net::HTTPSuccess, body: response_body)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:verify_mode=)
        allow(http).to receive(:verify_callback=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:request).and_return(response)

        result = checker.send(:fetch_latest_version)
        expect(result).to eq("1.2.3")
      end
    end

    context "when API returns error" do
      it "returns nil" do
        response = instance_double(Net::HTTPNotFound)
        allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)

        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:verify_mode=)
        allow(http).to receive(:verify_callback=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:request).and_return(response)

        result = checker.send(:fetch_latest_version)
        expect(result).to be_nil
      end
    end

    context "when network error occurs" do
      it "returns nil" do
        allow(Net::HTTP).to receive(:new).and_raise(SocketError.new("Network error"))

        result = checker.send(:fetch_latest_version)
        expect(result).to be_nil
      end
    end

    context "when timeout occurs" do
      it "returns nil" do
        allow(Net::HTTP).to receive(:new).and_raise(Net::OpenTimeout.new("Timeout"))

        result = checker.send(:fetch_latest_version)
        expect(result).to be_nil
      end
    end
  end
end
