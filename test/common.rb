# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'rubygems'
require 'bundler/setup'
require 'json'
gem 'minitest'
require 'minitest/unit'
require 'rack/test'
require 'redis'
require 'mock-pony'
require 'mock-renderer'

require 'simplecov'
SimpleCov.start

ENV['RACK_ENV'] = 'test'

module Stormy
  KeyPrefix = 'TEST:' unless const_defined?(:KeyPrefix)
end

require 'stormy'
require 'stormy/server'

module Stormy
  module Test

    class Unit < MiniTest::Unit

      def before_suites
      end

      def after_suites
        # nuke test data
        redis = Redis.new
        redis.keys(Stormy.key('*')).each do |key|
          redis.del key
        end
        if Pony.sent_mail.length > 0
          puts "\nLeftover mail: #{Pony.sent_mail.length}"
          Pony.sent_mail.each do |m|
            puts
            puts "To: #{m[:to]}"
            puts "From: #{m[:from]}"
            puts "Subject: #{m[:subject]}"
            puts "Content type: #{m[:content_type]}"
            puts m[:body]
          end
        end
      end

      def _run_suites(suites, type)
        begin
          before_suites
          super(suites, type)
        ensure
          after_suites
        end
      end

      def _run_suite(suite, type)
        begin
          suite.before_suite if suite.respond_to?(:before_suite)
          super(suite, type)
        ensure
          suite.after_suite if suite.respond_to?(:after_suite)
        end
      end

    end # Unit


    #############
    ### Cases ###
    #############

    class Case < Unit::TestCase

      include Stormy::Models

      def redis
        @redis ||= Redis.new
      end

      def fixtures(name)
        @_fixtures ||= {}
        @_fixtures[name] ||= JSON.parse(File.read(File.join(this_dir, "fixtures", "#{name}.json")))
      end

      def photo_file(filename)
        @_photos ||= {}
        @_photos[filename] ||= File.expand_path(File.join(this_dir, "photos", filename))
      end

      def video_file(filename)
        @_videos ||= {}
        @_videos[filename] ||= File.expand_path(File.join(this_dir, "videos", filename))
      end

      def erb(template, options = {}, locals = {})
        @renderer ||= MockRenderer.new
        @renderer.erb(template, options, locals)
      end


      private

      def this_dir
        @_this_dir ||= File.dirname(__FILE__)
      end

    end # Case


    class HelperCase < Case

      include Stormy::Helpers::Utils

    end # HelperCase


    class ControllerCase < Case

      include Rack::Test::Methods

      def app
        Stormy::Server
      end

      def session
        last_request.env['rack.session']
      end

      def flash
        session['flash']
      end

      def config
        @config ||= Stormy::Config.instance
      end

      def assert_response_json_equal(data)
        assert_equal data, JSON.parse(last_response.body)
      end

      def assert_response_json_ok(data = nil)
        assert_ok
        data = if data
                 { 'status' => 'ok', 'data' => data }
               else
                 { 'status' => 'ok' }
               end
        assert_response_json_equal data
      end

      def assert_response_json_fail(reason = nil)
        assert_ok
        data = if reason
                 { 'status' => 'fail', 'reason' => reason }
               else
                 { 'status' => 'fail' }
               end
        assert_response_json_equal data
      end

      def assert_ok
        puts last_response.body unless last_response.ok?
        assert last_response.ok?, "expected ok response 2xx, got #{last_response.status}"
      end

      def assert_bad_request
        assert_equal 400, last_response.status
      end

      def assert_not_authorized
        assert_equal 403, last_response.status
      end

      def assert_not_found
        assert_equal 404, last_response.status
      end

      def assert_redirected(path = nil)
        assert_equal 302, last_response.status, "expected 302 redirect, got #{last_response.status} (#{last_response.body})"
        if path
          url = if path.starts_with?('http')
            path
          else
            "http://example.org#{path}"
          end
          assert_equal url, last_response.headers['Location']
        end
      end

    end # ControllerCase


    ###############
    ### Helpers ###
    ###############

    module Helpers

      module Accounts

        include Stormy::Models

        def accounts
          @accounts ||= fixtures('accounts')
        end

        def setup_accounts
          @existing_account_data = accounts['sami']
          @existing_account = Account.create(@existing_account_data)

          @account_data = accounts['freddy']
        end

        def teardown_accounts
          if @signed_in
            @signed_in = false
            sign_out
          end
          Account.list_ids.each do |id|
            Account.delete!(id)
          end
        end

        def sign_in(account_data = @existing_account_data, options = {})
          post '/sign-in', account_data.merge(options)
          @signed_in = true
        end

        def sign_out
          post '/sign-out'
        end

      end # Accounts

    end # Helpers

  end
end

MiniTest::Unit.runner = Stormy::Test::Unit.new
MiniTest::Unit.autorun
