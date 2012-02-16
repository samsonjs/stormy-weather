#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class AuthorizationHelperTest < Stormy::Test::HelperCase

  include Stormy::Helpers::Authorization
  include Stormy::Test::Helpers::Accounts

  def setup
    setup_accounts
  end

  def teardown
    deauthorize
    teardown_request
    teardown_accounts
    @current_account = nil
  end

  def teardown_request
    @request = nil
    @redirect = nil
    @content_type = nil
    @session = nil
  end

  def assert_redirected(url)
    catch(:redirect) { yield } if block_given?
    assert_equal url, @redirect
  end

  def assert_not_redirected
    assert_nil @redirect
  end

  def assert_content_type(type)
    assert_equal type, @content_type
  end


  # Mock Rack and Sinatra methods

  def session
    @session ||= {}
  end

  def flash
    @session[:flash] ||= {}
  end

  def request
    unless @request
      @request = Object.new
      class <<@request
        def cookies
          @cookies ||= {}
        end

        def delete_cookie(name)
          cookies.delete(name)
        end

        def url
          '/account'
        end
      end
    end
    @request
  end

  def response
    request
  end

  def redirect(url)
    @redirect = url
    throw(:redirect)
  end

  def content_type(type)
    @content_type = type
  end


  #############
  ### Tests ###
  #############

  def test_authorize_account
    authorize_account(@existing_account.id)
    assert_equal @existing_account.id, session[:id]
    assert authorized?
  end

  def test_authorized?
    assert !authorized?
    authorize_account(@existing_account.id)
    assert authorized?

    authorize_account('does not exist')
    assert !authorized?
  end

  def test_authorized_when_remembered
    request.cookies['remembered'] = @existing_account.id
    assert authorized?
  end

  def test_authorize!
    authorize_account(@existing_account.id)
    authorize!
    assert_not_redirected
    assert !session.has_key?(:original_url)
  end

  def test_authorize_redirects_to_sign_in
    assert_redirected('/sign-in') { authorize! }
    assert_equal request.url, session[:original_url]
  end

  def test_authorize_api!
    authorize_account(@existing_account.id)
    assert_nil catch(:halt) { authorize_api! }
  end

  def test_authorize_api_throws_if_unauthorized
    assert_equal not_authorized, catch(:halt) { authorize_api! }
    assert_content_type 'text/plain'
  end

  def test_deauthorize
    authorize_account(@existing_account.id)
    request.cookies['remembered'] = @existing_account.id

    deauthorize
    assert !authorized?
    assert !session.has_key?(:id)
    assert !request.cookies.has_key?('remembered')
  end

  def test_current_account
    assert_nil current_account

    authorize_account(@existing_account.id)
    assert_equal @existing_account.id, current_account.id
  end

  def test_admin_authorized?
    assert !admin_authorized?
    authorize_account(@existing_account.id)
    assert admin_authorized?

    authorize_account('does not exist')
    assert !admin_authorized?
  end

  def test_admin_authorize!
    authorize_account(@existing_account.id)
    admin_authorize!
    assert_not_redirected
    assert !session.has_key?(:original_url)
  end

  def test_admin_authorize_redirects_to_sign_in
    assert_redirected('/sign-in') { admin_authorize! }
    assert_equal request.url, session[:original_url]
  end

  def test_admin_authorize_api!
    authorize_account(@existing_account.id)
    assert_nil catch(:halt) { admin_authorize_api! }
  end

  def test_admin_authorize_api_throws_if_unauthorized
    assert_equal not_authorized, catch(:halt) { admin_authorize_api! }
    assert_content_type 'text/plain'
  end

end
