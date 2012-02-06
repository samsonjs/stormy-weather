# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'rubygems'
require 'bundler/setup'
require 'pony'

module Pony

  @@sent_mail = []

  def self.mail(options)
    sent_mail << options
  end

  def self.sent_mail
    @@sent_mail
  end

end
