#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'bcrypt'

puts BCrypt::Password.create(ARGV.first)
