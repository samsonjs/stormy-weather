#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AccountsControllerTest < Stormy::Test::ControllerCase

  include Stormy::Test::Helpers::Accounts
  include Stormy::Test::Helpers::Projects

  def setup
    setup_accounts
  end

  def teardown
    teardown_accounts
  end


  ###############
  ### Sign Up ###
  ###############

  def test_sign_up
    # populate session['source'] and session['source_info']
    get '/promo'

    get '/sign-up', {}
    assert_ok
  end

  def test_sign_up_with_valid_data
    post '/sign-up', @account_data
    assert_redirected '/projects'
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end

  def test_sign_up_with_missing_fields
    account_data = @account_data.dup

    # first name
    account_data['first_name'] = nil
    post '/sign-up', account_data
    assert_redirected '/sign-up'

    # last name
    account_data['last_name'] = nil
    post '/sign-up', account_data
    assert_redirected '/sign-up'

    # password
    account_data['password'] = nil
    post '/sign-up', account_data
    assert_redirected '/sign-up'
  end

  def test_sign_up_with_invalid_data
    account_data = @account_data.dup
    account_data['email'] = 'not an email address'
    post '/sign-up', account_data
    assert_redirected '/sign-up'
  end

  def test_sign_up_with_existing_email
    post '/sign-up', @existing_account_data
    assert_redirected '/sign-up'
  end


  #####################
  ### Authorization ###
  #####################

  def test_sign_in
    get '/sign-in'
    assert_ok
  end

  def test_sign_in_submit
    sign_in
    assert_redirected '/projects'
  end

  def test_sign_in_remember
    sign_in(@existing_account_data, 'remember' => 'on')
    assert_redirected '/projects'

    post '/sign-out'
    assert_redirected '/'

    get '/projects'
    assert_ok

    # deletes remembered cookie
    sign_in
  end

  def test_sign_in_with_invalid_credentials
    sign_in(@account_data)
    assert_redirected '/sign-in'
  end

  def test_sign_in_redirect
    # authorized page redirects to sign-in
    get '/account'
    assert_redirected '/sign-in'

    # redirects to original URL after signing in
    sign_in
    assert_redirected '/account'
  end

  def test_sign_out
    post '/sign-out'
    assert_redirected '/'
  end

  def test_forgot_password
    get '/forgot-password'
    assert_ok
  end

  def test_forgot_password_existing_email
    post '/forgot-password', { :email => @existing_account.email }
    assert_redirected '/sign-in'
    assert Account.fetch(@existing_account.id).password_reset_token
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end

  def test_forgot_password_non_existent_email
    post '/forgot-password', { :email => 'not a real email' }
    assert_redirected '/forgot-password'
  end

  def test_forgot_password_missing_email
    post '/forgot-password', { :email => '' }
    assert_redirected '/forgot-password'
  end

  def test_reset_password
    email = @existing_account.email
    post '/forgot-password', { :email => email }
    assert_redirected '/sign-in'

    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift

    token = Account.fetch(@existing_account.id).password_reset_token
    get "/sign-in/#{email}/#{token}"
    assert_ok

    new_password = 'new password'
    post '/account/reset-password', { 'password' => new_password }
    assert_redirected '/projects'
    assert_equal @existing_account.id, Account.check_password(@existing_account.email, new_password)
    assert Account.fetch(@existing_account.id).password == new_password

    # token is only good for one use
    get "/sign-in/#{email}/#{token}"
    assert_redirected "/forgot-password/#{email}"
  end


  ###############
  ### Account ###
  ###############

  def test_account
    sign_in
    get '/account'
    assert_ok
  end

  def test_account_password
    sign_in
    new_password = 'my new password'
    post '/account/password', {
      'old-password'          => @existing_account_data['password'],
      'new-password'          => new_password,
      'password-confirmation' => new_password
    }
    assert_response_json_ok
  end

  def test_account_password_incorrect
    sign_in
    post '/account/password', {
      'old-password'          => 'wrong password',
      'new-password'          => 'irrelevant',
      'password-confirmation' => 'irrelevant'
    }
    assert_response_json_fail 'incorrect'
  end

  def test_account_password_invalid
    sign_in
    post '/account/password', {
      'old-password'          => @existing_account_data['password'],
      'new-password'          => ' ',
      'password-confirmation' => ' '
    }
    assert_response_json_fail 'invalid'
  end

  def test_account_update_json
    sign_in

    # email
    post '/account/update.json', { :id => 'email', :value => @existing_account.email }
    # noop, but is ok
    assert_response_json_ok
    # does not send email verification mail
    assert_equal 0, Pony.sent_mail.length

    post '/account/update.json', { :id => 'email', :value => 'sami-different@example.com' }
    assert_response_json_ok
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift

    post '/account/update.json', { :id => 'email', :value => 'not an email address' }
    assert_response_json_fail 'invalid'

    other_account = Account.create(@account_data)
    post '/account/update.json', { :id => 'email', :value => other_account.email }
    assert_response_json_fail 'taken'
    other_account.delete!
  end

  def test_account_update
    sign_in

    # valid data
    new_phone = '640-555-1234'
    post '/account/update', { 'id' => 'phone', 'value' => new_phone }
    assert_ok
    assert_equal new_phone, last_response.body

    # invalid data
    post '/account/update', { 'id' => 'first_name', 'value' => '' }
    assert_bad_request

    # non-updatable fields are ignored, but treated the same as updatable fields from the server's perspective
    post '/account/update', { 'id' => 'email_verified', 'value' => 'true' }
    assert_ok
    assert_equal 'true', last_response.body
  end


  ####################
  ### Verification ###
  ####################

  def test_verify_email
    get "/account/verify/#{@existing_account.email}/#{@existing_account.email_verification_token}"
    assert_redirected '/account'
    assert_nil Account.fetch(@existing_account.id).email_verification_token
  end

  def test_verify_email_with_invalid_token_signed_in
    sign_in
    get "/account/verify/#{@existing_account.email}/not-a-real-token"
    assert_redirected '/account'
    assert_equal @existing_account.email_verification_token, Account.fetch(@existing_account.id).email_verification_token
  end

  def test_verify_email_with_invalid_token_not_signed_in
    get "/account/verify/#{@existing_account.email}/not-a-real-token"
    assert_ok
    assert_equal @existing_account.email_verification_token, Account.fetch(@existing_account.id).email_verification_token
  end

  def test_account_send_email_verification
    sign_in
    post '/account/send-email-verification'
    assert_response_json_ok
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end

end
