#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AdminControllerTest < Stormy::Test::ControllerCase

  include Stormy::Test::Helpers::Accounts
  include Stormy::Test::Helpers::Projects
  include Stormy::Helpers::Admin
  include Stormy::Helpers::FAQ
  include Stormy::Helpers::Utils

  def admins
    @admins ||= fixtures('admins')
  end

  def setup
    @existing_admin_data = admins['sami']
    @existing_admin = Admin.create(@existing_admin_data)

    @admin_data = admins['freddy']
  end

  def teardown
    post '/admin/sign-out'
    Admin.list_ids.each do |id|
      Admin.delete!(id)
    end
  end

  def sign_in(admin = @existing_admin_data)
    post '/admin/sign-in', admin
  end


  #####################
  ### Sign In & Out ###
  #####################

  def test_sign_in
    get '/admin/sign-in'
    assert_ok
  end

  def test_sign_in_submit
    sign_in
    assert_redirected '/admin'
  end

  def test_sign_in_with_invalid_credentials
    sign_in(@admin_data)
    assert_redirected '/admin/sign-in'
  end

  def test_sign_in_redirect
    sign_in
    assert_redirected '/admin'
  end

  def test_sign_out
    post '/admin/sign-out'
    assert_redirected '/admin'
  end


  ############################
  ### Dashboard & Password ###
  ############################

  def test_dashboard
    sign_in
    get '/admin'
    assert_ok
    assert last_response.body.match(/<title>Dashboard/)
  end

  def test_change_password
    sign_in
    get '/admin/password'
    assert_ok

    new_password = 'new password'
    post '/admin/password', { 'password' => new_password, 'password_confirmation' => new_password }
    assert_redirected '/admin'
    @existing_admin.reload!
    assert @existing_admin.password == new_password

    # incorrect confirmation
    post '/admin/password', { 'password' => new_password, 'password_confirmation' => 'oops' }
    assert_redirected '/admin/password'
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
    setup_accounts
    sign_in

    get '/admin/account/' + @existing_account.email
    assert_ok

    get '/admin/account/not@an.account'
    # this was the previous listing, kind of weird but meh
    assert_redirected '/admin/account/' + @existing_account.email

    teardown_accounts
  end

  def test_update_account
    setup_accounts
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

    teardown_accounts
  end

  def test_sign_in_as_user
    setup_accounts
    sign_in

    get '/admin/sign-in-as/' + @existing_account.email
    assert_equal @existing_account.id, session[:id]
    assert_redirected '/projects'

    teardown_accounts
  end

  def test_delete_account
    setup_accounts
    setup_projects
    sign_in

    # make sure the last listing is marked so we are redirected correctly
    get '/admin/accounts'
    assert_ok

    get "/admin/account/#{@existing_account.email}/delete"
    assert_redirected '/admin/accounts'

    assert_nil Account.fetch(@existing_account.id)
    assert_nil Project.fetch(@existing_project.id)

    # non-existent accounts are already gone, so no problem
    get "/admin/account/nobody@nowhere.net/delete"

    # this time the last listing was not marked, so we are redirected to the dashboard
    assert_redirected '/admin'

    teardown_projects
    teardown_accounts
  end


  ################
  ### Projects ###
  ################

  def test_projects
    setup_accounts
    setup_projects
    sign_in

    get '/admin/projects'
    assert_ok

    teardown_projects
    teardown_accounts
  end

  def test_project
    setup_accounts
    setup_projects
    sign_in

    # non-existent project
    get '/admin/project/999'
    assert_redirected '/admin'

    # existing project
    get '/admin/project/' + @existing_project.id
    assert_ok

    teardown_projects
    teardown_accounts
  end

  def test_delete_project
    setup_accounts
    setup_projects
    sign_in

    # make sure the last listing is marked so we are redirected correctly
    get '/admin/projects'

    get "/admin/project/#{@existing_project.id}/delete"
    assert_redirected '/admin/projects'
    assert_nil Project.fetch(@existing_project.id)

    teardown_projects
    teardown_accounts
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


  ######################
  ### Admin Accounts ###
  ######################

  def test_admins
    sign_in
    get '/admin/admins'
    assert_ok
  end

  def test_add_admin
    sign_in

    password = 'password'
    fields = {
      'name'                  => 'Freddy Kruger',
      'email'                 => 'freddy@example.com',
      'password'              => password,
      'password_confirmation' => password
    }
    post '/admin/admins', fields
    assert_redirected '/admin/admins'
    admin = Admin.fetch_by_email('freddy@example.com')
    assert admin.password == password
    assert_equal fields['name'], admin.name
    assert_equal fields['email'], admin.email

    # passwords do not match
    fields = {
      'name'                  => 'Jason Vorhees',
      'email'                 => 'jason@example.com',
      'password'              => 'my password',
      'password_confirmation' => 'not the same password'
    }
    post '/admin/admins', fields
    assert_redirected '/admin/admins'
    assert_nil Admin.fetch_by_email('jason@example.com')
  end

  def test_delete_admin
    sign_in
    get "/admin/admins/#{@existing_admin.id}/delete"
    assert_redirected '/admin/admins'
    assert_equal 0, Admin.count
  end

end
