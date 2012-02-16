#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AccountTest < Stormy::Test::Case

  include Stormy::Test::Helpers::Accounts

  def setup
    setup_accounts

    @invalid_addresses = [
      'invalid email address',
      'invalid@email@address',
      'invalid.email.address',
      'invalid.email@address'
    ]
  end

  def teardown
    teardown_accounts
  end


  ### Class Methods

  def test_check_password
    assert_equal @existing_account.id, Account.check_password(@existing_account.email, @existing_account_data['password'])
    assert_equal @existing_account.id, Account.check_password(@existing_account.email.upcase, @existing_account_data['password'])
    assert !Account.check_password(@existing_account.email, 'incorrect password')
    assert !Account.check_password('non@existent.email', 'any password')
  end

  def test_email_taken?
    assert Account.email_taken?(@existing_account.email)
    assert !Account.email_taken?('freddy@example.com'), "New email is reported as taken"
  end

  def test_fetch_existing_by_email
    account = Account.fetch_by_email(@existing_account.email)
    assert account
    assert_equal @existing_account.id, account.id
    check_account_fields(account, @existing_account_data)
  end

  def test_fetch_nonexistent_by_email
    assert_nil Account.fetch_by_email('this is not a real email')
  end

  def test_reset_password
    data = Account.reset_password(@existing_account.email)
    assert_equal @existing_account.first_name, data['name']
    assert data['token']

    assert !Account.reset_password('non@existent.email')
  end

  def test_use_password_reset_token
    data = Account.reset_password(@existing_account.email)
    assert_equal @existing_account.id, Account.use_password_reset_token(@existing_account.email, data['token'])
  end

  def test_id_from_email
    assert_equal @existing_account.id, Account.id_from_email(@existing_account.email)
    assert_nil Account.id_from_email('not a real email')
  end

  def test_verify_email
    assert !Account.verify_email(@existing_account.email, 'invalid token')
    assert Account.verify_email(@existing_account.email, @existing_account.email_verification_token)
    account = Account.fetch(@existing_account.id)
    assert account.email_verified
    assert !account.instance_variable_get('@email_verification_token')
    assert !Account.verify_email('non@existent.email', 'insignificant token')
  end

  def test_email_verified?
    assert !Account.email_verified?(@existing_account.email)
    Account.verify_email(@existing_account.email, @existing_account.email_verification_token)
    assert Account.email_verified?(@existing_account.email)
  end

  def test_creates_email_verification_token
    assert @existing_account.email_verification_token

    # no new token is generated if one is present
    token = @existing_account.email_verification_token
    assert_equal @existing_account.email_verification_token, token

    # a token is generated if necessary
    Account.verify_email(@existing_account.email, @existing_account.email_verification_token) # clears token
    account = Account.fetch(@existing_account.id)
    assert !account.instance_variable_get('@email_verification_token')
    assert account.email_verification_token != token
  end


  ### Instance Methods

  def check_account_fields(account, fields)
    fields.each do |key, expected|
      if key == 'password'
        assert account.password == fields['password'], "<#{fields['password'].inspect}> expected but was <#{account.password.inspect}>"
      else
        actual = account.send(key)
        assert_equal expected, actual, "#{key}: <#{expected.inspect}> expected but was <#{actual.inspect}>"
      end
    end
  end

  def test_create
    assert @existing_account
    assert @existing_account.id
    assert @existing_account.email_verification_token

    # creation time can be 1 - 2 seconds in the past
    delta = (Time.now.to_i - @existing_account.created_timestamp).abs
    assert delta < 3

    check_account_fields(@existing_account, @existing_account_data)

    # indexes
    assert Account.fetch_by_email(@existing_account.email)
  end

  def test_create_with_existing_email
    assert_raises Account::DuplicateFieldError do
      Account.new(@existing_account_data).create
    end
  end

  def test_create_with_missing_fields
    # first name
    assert_raises Account::InvalidDataError do
      Account.create({ 'last_name' => 'Kruger', 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => ' ', 'last_name' => 'Kruger', 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end

    # last name
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'last_name' => ' ', 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end

    # email
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'last_name' => 'Kruger', 'password' => 'secret password' })
    end
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'last_name' => 'Kruger', 'email' => ' ', 'password' => 'secret password' })
    end

    # password
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'last_name' => 'Kruger', 'email' => 'freddy@example.com' })
    end
    assert_raises Account::InvalidDataError do
      Account.create({ 'first_name' => 'Freddy', 'last_name' => 'Kruger', 'email' => 'freddy@example.com', 'password' => ' ' })
    end
  end

  def test_create_with_invalid_fields
    data = {
      'first_name' => 'Sami',
      'last_name' => 'Samhuri',
      'password' => 'secret password'
    }

    original_email = data['email']
    @invalid_addresses.each do |email|
      data['email'] = email
      assert_raises Account::InvalidDataError do
        Account.create(data)
      end
    end
    data['email'] = original_email
  end

  def test_delete!
    @existing_account.delete!

    assert Account.fetch(@existing_account.id).nil?, 'Account was fetched by id after deletion'
    assert Account.fetch_by_email(@existing_account.email).nil?, 'Account was fetched by email after deletion'

    # indexes
    assert !@existing_account.email_taken?(@existing_account.email), 'Account email is taken after deletion'
    assert !Account.exists?(@existing_account.id), 'Account exists after deletion'
  end

  def test_name
    assert_equal "#{@existing_account.first_name} #{@existing_account.last_name}", @existing_account.name
  end

  def test_update
    original_data = {
      'id'        => @existing_account.id,
      'email'     => @existing_account.email,
      'phone'     => @existing_account.phone
    }
    
    updated_data = {
      # updatable
      'first_name'          => 'Samson',
      'last_name'           => 'Simpson',
      'phone'               => '+12509991234',
      
      # not updatable
      'id'                  => 'should be ignored',
      'email'               => 'should be ignored',
      'password'            => 'should be ignored'
    }
    @existing_account.update(updated_data)

    # should be updated
    assert_equal updated_data['first_name'], @existing_account.first_name
    assert_equal updated_data['last_name'], @existing_account.last_name
    assert_equal updated_data['phone'], @existing_account.phone

    # should not be updated
    assert_equal original_data['id'], @existing_account.id
    assert_equal original_data['email'], @existing_account.email
    assert @existing_account.password != updated_data['password']
    assert @existing_account.password == @existing_account_data['password']
  end

  def test_update_with_invalid_fields
    assert_raises Account::InvalidDataError do
      @existing_account.update(:first_name => ' ')
    end
    assert_raises Account::InvalidDataError do
      @existing_account.update(:last_name => ' ')
    end

    # phone number
    invalid_numbers = [
      '+44 123 456 7890', # too long, wrong country code
      '123'               # too short, not a real phone number
    ]

    invalid_numbers.each do |number|
      assert_raises Account::InvalidDataError do
        @existing_account.update(:phone => number)
      end
    end
  end

  def test_update_email
    # pretend this address is verified
    @existing_account.email_verified = true
    @existing_account.save

    new_email = 'sami-different@example.com'
    old_email = @existing_account.email

    # updates database immediately
    @existing_account.update_email(new_email)
    assert_equal new_email, @existing_account.email
    assert_equal new_email, Account.fetch(@existing_account.id).email

    # new email addresses are not verified
    assert !@existing_account.email_verified, "Email address should not be verified"
    assert !Account.fetch(@existing_account.id).email_verified

    # index is updated
    assert Account.email_taken?(new_email)
    assert !Account.email_taken?(old_email)

    # no change in address is a noop
    @existing_account.update_email(new_email)

    # invalid addresses are rejected
    @invalid_addresses.each do |email|
      assert_raises Account::InvalidDataError do
        @existing_account.update_email(email)
      end
    end
  end

  def test_update_email_changing_only_case
    # pretend this address is verified
    @existing_account.email_verified = true
    @existing_account.save

    # change only the case
    loud_email = @existing_account.email.upcase
    @existing_account.update_email(loud_email)
    assert_equal loud_email, @existing_account.email

    # a mere change of case does not reset verified flag
    assert @existing_account.email_verified
    assert Account.fetch(@existing_account.id).email_verified

    # is still indexed properly
    assert Account.email_taken?(loud_email)
  end

  def test_update_password
    old_password = @existing_account_data['password']
    new_password = 'the new password'
    @existing_account.update_password(old_password, new_password)
    assert @existing_account.password == new_password
    assert Account.fetch(@existing_account.id).password == new_password

    assert_raises Account::IncorrectPasswordError do
      @existing_account.update_password('incorrect', 'irrelevant')
    end

    assert_raises Account::InvalidDataError do
      @existing_account.update_password(new_password, ' ')
    end
  end

  def test_update!
    original_data = {
      'id'        => @existing_account.id,
      'email'     => @existing_account.email,
      'phone'     => @existing_account.phone
    }
    
    updated_data = {
      # updatable
      'first_name'          => 'Samson',
      'last_name'           => 'Simpson',
      'phone'               => '+12509995534',
      
      # not updatable
      'id'                  => 'should be updated',
      'email'               => 'should be updated',
      'password'            => 'should be updated'
    }
    @existing_account.update!(updated_data)

    # all should be updated
    check_account_fields(@existing_account, updated_data)

    # restore fields required for clean up
    @existing_account.update!(original_data)
  end

end
