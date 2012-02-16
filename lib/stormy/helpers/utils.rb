# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'json'
require 'stormy/config'

module Stormy
  module Helpers
    module Utils

      def config
        @config ||= Stormy::Config.instance
      end

      def redis
        @redis ||= Redis.new
      end

      def testing?
        ENV['RACK_ENV'] == 'test'
      end

      def production?
        ENV['RACK_ENV'] == 'production'
      end

      def development?
        ENV['RACK_ENV'] == 'development'
      end

      # JSON responses for API endpoints

      def ok(data = nil)
        if data.nil?
          { 'status' => 'ok' }
        else
          { 'status' => 'ok', 'data' => data }
        end.to_json
      end

      def fail(reason = nil)
        if reason.nil?
          { 'status' => 'fail' }
        else
          { 'status' => 'fail', 'reason' => reason }
        end.to_json
      end

      def bad_request
        [400, "Bad request\n"]
      end

      def not_authorized
        [403, "Not authorized\n"]
      end

      def base_url
        @base_url ||= production? ? "http://dev.example.com:#{settings.port}/" : "http://localhost:#{settings.port}/"
      end

      def url_for(*args)
        "#{base_url}#{args.join('/')}"
      end

    end
  end
end
