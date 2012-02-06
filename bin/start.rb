#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'stormy'
require 'stormy/server'

Stormy::Server.run!
