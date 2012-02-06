#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

$LOAD_PATH.unshift('lib')
require 'stormy'
require 'stormy/server'

run Stormy::Server
