#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AccountsHelperTest < Stormy::Test::HelperCase

  include Stormy::Helpers::Accounts
  include Stormy::Test::Helpers::Accounts
  include Stormy::Test::Helpers::Projects

  def setup
    setup_accounts
  end

  def teardown
    teardown_accounts
  end


  ######################
  ### Password Reset ###
  ######################

  def test_send_reset_password_mail
    data = send_reset_password_mail(@existing_account.email)
    @existing_account.reload!
    assert data
    assert_equal @existing_account.first_name, data['name']
    assert_equal @existing_account.password_reset_token, data['token']
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end


  ####################
  ### Verification ###
  ####################

  def test_send_verification_mail
    send_verification_mail(@existing_account)
    assert @existing_account.email_verification_token.present?
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift

    send_verification_mail(@existing_account, 'custom subject')
    assert_equal 1, Pony.sent_mail.length
    assert mail = Pony.sent_mail.shift
  end

end
