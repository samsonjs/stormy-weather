# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'date'

require 'rubygems'
require 'bundler/setup'
require 'active_support/core_ext'

this_dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(this_dir) unless $LOAD_PATH.include?(this_dir)

# Ruby extensions
require 'class-ext'
require 'hash-ext'

module Stormy

  # key prefix for data stored in Redis (used for testing)
  unless const_defined? :KeyPrefix
    KeyPrefix = ''
  end

  # public directory for photos
  unless const_defined? :PhotoDir
    PhotoDir = File.expand_path('../public/photos', File.dirname(__FILE__))
  end

  # public directory for videos
  unless const_defined? :VideoDir
    VideoDir = File.expand_path('../public/videos', File.dirname(__FILE__))
  end

  def self.key_prefix
    @key_prefix ||= "#{KeyPrefix}stormy:"
  end

  def self.key(*components)
    key_prefix + components.compact.join(':')
  end

end
