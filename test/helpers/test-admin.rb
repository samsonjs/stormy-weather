#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AdminHelperTest < Stormy::Test::HelperCase

  include Stormy::Helpers::Admin

  def session
    @session ||= {}
  end

  def test_num_accounts
    assert_equal 0, num_accounts
  end

  def test_last_listing
    assert_equal '/admin', last_listing
    mark_last_listing '/admin/accounts'
    assert_equal '/admin/accounts', last_listing
  end

  def test_mark_last_listing
    assert_equal '/admin', last_listing
    mark_last_listing '/admin/accounts'
    assert_equal '/admin/accounts', last_listing
  end

end
