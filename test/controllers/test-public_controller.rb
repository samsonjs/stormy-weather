#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class PublicControllerTest < Stormy::Test::ControllerCase

  def test_home
    get '/'
    assert_ok
  end

  def test_contact
    get '/contact'
    assert_ok
  end

  def test_contact_form
    post '/contact', { 'email' => 'sami@example.com', 'message' => 'please get back to me...' }
    assert_redirected '/contact'
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end

  def test_terms
    get '/terms'
    assert_ok
  end

  def test_faq
    get '/faq'
    assert_ok
  end

end
