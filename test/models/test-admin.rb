#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AdminTest < Stormy::Test::Case

  def setup
    admins = fixtures('admins')
    @admin_data = admins['sami']
    @admin = Admin.create(@admin_data)

    @invalid_addresses = [
      'invalid email address',
      'invalid@email@address',
      'invalid.email.address',
      'invalid.email@address'
    ]
  end

  def teardown
    @admin.delete!
  end


  ### Class Methods

  def test_key_from_email
    assert_equal @admin.send(:key), Admin.key_from_email(@admin.email)
    assert_nil Admin.key_from_email('not a real email')
  end

  def test_check_password
    assert_equal @admin.id, Admin.check_password(@admin.email, @admin_data['password'])
    assert_equal @admin.id, Admin.check_password(@admin.email.upcase, @admin_data['password'])
    assert !Admin.check_password(@admin.email, 'incorrect password')
    assert !Admin.check_password('non@existent.email', 'any password')
  end

  def test_email_taken?
    assert Admin.email_taken?(@admin.email)
    assert !Admin.email_taken?('freddy@example.com'), "New email is reported as taken"
  end

  def test_fetch_existing_by_id
    admin = Admin.fetch(@admin.id)
    assert admin
    assert_equal @admin.id, admin.id
    check_admin_fields(admin, @admin_data)
  end

  def test_fetch_nonexistent_by_id
    assert_nil Admin.fetch('this is not a real id')
  end

  def test_fetch_existing_by_email
    admin = Admin.fetch_by_email(@admin.email)
    assert admin
    assert_equal @admin.id, admin.id
    check_admin_fields(admin, @admin_data)
  end

  def test_fetch_nonexistent_by_email
    assert_nil Admin.fetch_by_email('this is not a real email')
  end

  def test_id_from_email
    assert_equal @admin.id, Admin.id_from_email(@admin.email)
    assert_nil Admin.id_from_email('not a real email')
  end


  ### Instance Methods

  def check_admin_fields(admin, fields)
    fields.each do |key, expected|
      if key == 'password'
        assert admin.password == fields['password'], "<#{fields['password'].inspect}> expected but was <#{admin.password.inspect}>"
      else
        actual = admin.send(key)
        assert_equal expected, actual, "#{key}: <#{expected.inspect}> expected but was <#{actual.inspect}>"
      end
    end
  end

  def test_create
    assert @admin
    assert @admin.id
    check_admin_fields(@admin, @admin_data)

    # indexes
    assert Admin.fetch_by_email(@admin.email)
  end

  def test_create_with_existing_email
    assert_raises Admin::EmailTakenError do
      Admin.new(@admin_data).create
    end
  end

  def test_create_with_missing_fields
    # name
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'name' => ' ', 'email' => 'freddy@example.com', 'password' => 'secret password' })
    end

    # email
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'name' => 'Freddy', 'password' => 'secret password' })
    end
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'name' => 'Freddy', 'email' => ' ', 'password' => 'secret password' })
    end

    # password
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'name' => 'Freddy', 'email' => 'freddy@example.com' })
    end
    assert_raises Admin::InvalidDataError do
      Admin.create({ 'name' => 'Freddy', 'email' => 'freddy@example.com', 'password' => ' ' })
    end
  end

  def test_create_with_invalid_fields
    data = {
      'name'     => 'Freddy',
      'password' => 'secret password'
    }

    @invalid_addresses.each do |email|
      data['email'] = email
      assert_raises Admin::InvalidDataError do
        Admin.create(data)
      end
    end
  end

  def test_delete!
    @admin.delete!

    assert Admin.fetch(@admin.id).nil?, 'Admin was fetched by id after deletion'
    assert Admin.fetch_by_email(@admin.email).nil?, 'Admin was fetched by email after deletion'

    # indexes
    assert !@admin.email_taken?, 'Admin email is taken after deletion'
    assert !Admin.exists?(@admin.id), 'Admin exists after deletion'
  end

  def test_update
    original_data = {
      'id'        => @admin.id,
      'email'     => @admin.email,
    }

    updated_data = {
      # updatable
      'name'                => 'Samson',
      
      # not updatable
      'id'                  => 'should be ignored',
      'email'               => 'should be ignored',
      'password'            => 'should be ignored',
    }
    @admin.update(updated_data)

    # should be updated
    assert_equal updated_data['name'], @admin.name

    # should not be updated
    assert_equal original_data['id'], @admin.id
    assert_equal original_data['email'], @admin.email
    assert @admin.password != updated_data['password']
    assert @admin.password == @admin_data['password']
  end

  def test_update_with_invalid_fields
    assert_raises Admin::InvalidDataError do
      @admin.update({ 'name' => ' ' })
    end
  end

  def test_update_email
    # pretend this address is verified
    new_email = 'sami-different@example.com'
    old_email = @admin.email

    # updates database immediately
    @admin.update_email(new_email)
    assert_equal new_email, @admin.email
    assert_equal new_email, Admin.fetch(@admin.id).email

    # index is updated
    assert Admin.email_taken?(new_email)
    assert !Admin.email_taken?(old_email)

    # no change in address is a noop
    @admin.update_email(new_email)

    # invalid addresses are rejected
    @invalid_addresses.each do |email|
      assert_raises Admin::InvalidDataError do
        @admin.update_email(email)
      end
    end
  end

  def test_update_email_changing_only_case
    # change only the case
    loud_email = @admin.email.upcase
    @admin.update_email(loud_email)
    assert_equal loud_email, @admin.email

    # is still indexed properly
    assert Admin.email_taken?(loud_email)
  end

  def test_update_password
    old_password = @admin_data['password']
    new_password = 'the new password'
    @admin.update_password(old_password, new_password)
    assert @admin.password == new_password
    assert Admin.fetch(@admin.id).password == new_password

    assert_raises Admin::IncorrectPasswordError do
      @admin.update_password('incorrect', 'irrelevant')
    end

    assert_raises Admin::InvalidDataError do
      @admin.update_password(new_password, ' ')
    end
  end

end
