# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'rubygems'
require 'bundler/setup'
require 'sinatra'

module Stormy
  module Test
    class MockRenderer

      include Sinatra::Templates

      attr_accessor :template_cache

      def initialize
        super
        self.template_cache = Tilt::Cache.new
      end

      def erb(template, options = {}, locals = {})
        super(template, options.merge({ :views => File.dirname(__FILE__) + '/../views' }), locals)
      end

    end
  end
end
