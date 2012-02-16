#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AdminControllerTest < Stormy::Test::ControllerCase

  include Stormy::Test::Helpers::Accounts
  include Stormy::Helpers::Admin
  include Stormy::Helpers::FAQ
  include Stormy::Helpers::Utils

  def setup
    setup_accounts
  end

  def teardown
    post '/sign-out'
    teardown_accounts
  end

  def sign_in(admin = @existing_account_data)
    post '/sign-in', admin
  end


  #################
  ### Dashboard ###
  #################

  def test_dashboard
    sign_in
    get '/admin'
    assert_ok
    assert last_response.body.match(/<title>[^<]*Dashboard[^<]*<\/title>/)
  end


  ################
  ### Accounts ###
  ################

  def test_accounts
    sign_in
    get '/admin/accounts'
    assert_ok
  end

  def test_account
    sign_in

    get '/admin/account/' + @existing_account.email
    assert_ok

    get '/admin/account/not@an.account'
    # this was the previous listing, kind of weird but meh
    assert_redirected '/admin/account/' + @existing_account.email
  end

  def test_update_account
    sign_in

    # redirected to proper page when changing email addresses
    new_email = 'sami-different@example.com'
    post '/admin/account/' + @existing_account.email, {
      'new_email' => new_email,
      'first_name' => 'Samson',
      'last_name' => 'Simpson',
      'phone' => '+12501234567'
    }
    assert_redirected '/admin/account/' + new_email
    @existing_account.reload!
    assert_equal 'Samson', @existing_account.first_name
    assert_equal 'Simpson', @existing_account.last_name
    assert_equal new_email, @existing_account.email

    # email is verified if changed, verification status stays the same if not changed
    assert @existing_account.email_verified?

    # redirected to dashboard for non-existent email
    post '/admin/account/' + @account_data['email']
    assert_redirected '/admin'

    # redirected to original page if email is taken
    @account = Account.create(@account_data)
    post '/admin/account/' + @existing_account.email, {
      'new_email' => @account.email
    }
    assert_redirected '/admin/account/' + @existing_account.email

    # redirected to account page if fields are invalid
    post '/admin/account/' + @existing_account.email, {
      'first_name' => '',
      'last_name'  => '',
      'phone'      => ''
    }
    assert_redirected '/admin/account/' + @existing_account.email

    # not updated
    @existing_account.reload!
    assert_equal 'Samson', @existing_account.first_name
    assert_equal 'Simpson', @existing_account.last_name
    assert_equal '+12501234567', @existing_account.phone
  end

  def test_sign_in_as_user
    sign_in

    get '/admin/sign-in-as/' + @existing_account.email
    assert_equal @existing_account.id, session[:id]
    assert_redirected '/account'
  end

  def test_delete_account
    sign_in

    # make sure the last listing is marked so we are redirected correctly
    get '/admin/accounts'
    assert_ok

    @other_account = Account.create(@account_data)
    get "/admin/account/#{@other_account.email}/delete"
    assert_redirected '/admin/accounts'

    assert_nil Account.fetch(@other_account.id)

    # non-existent accounts are already gone, so no problem
    get "/admin/account/nobody@nowhere.net/delete"

    # this time the last listing was not marked, so we are redirected to the dashboard
    assert_redirected '/admin'
  end


  ###########
  ### FAQ ###
  ###########

  def test_faq
    sign_in
    get '/admin/faq'
    assert_ok
  end

  def test_update_faq
    sign_in
    original_faq = faq

    new_faq = 'this is the new faq'
    post '/admin/faq', 'faq' => new_faq
    assert_redirected '/admin/faq'
    assert_equal new_faq, faq

    # restore the original value
    self.faq = original_faq
  end

end
