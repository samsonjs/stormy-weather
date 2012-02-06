#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class UtilsHelperTest < Stormy::Test::HelperCase

  def teardown
    ENV['RACK_ENV'] = 'test'
    @base_url = nil
  end


  def test_config
    assert config
  end

  def test_redis
    assert redis
  end

  def test_testing?
    assert testing?
    ENV['RACK_ENV'] = 'development'
    assert !testing?
  end

  def test_production?
    assert !production?
    ENV['RACK_ENV'] = 'production'
    assert production?
  end

  def test_development?
    assert !development?
    ENV['RACK_ENV'] = 'development'
    assert development?
  end

  def assert_json_equal(a, b, reason = nil)
    assert_equal a.to_json, b, reason
  end

  def test_ok
    assert_json_equal({ 'status' => 'ok' }, ok)
    assert_json_equal({ 'status' => 'ok', 'data' => 42 }, ok(42))
    assert_json_equal({ 'status' => 'ok', 'data' => { 'foo' => 'bar' } }, ok('foo' => 'bar'))
  end

  def test_fail
    assert_json_equal({ 'status' => 'fail' }, fail)
    assert_json_equal({ 'status' => 'fail', 'reason' => 42 }, fail(42))
    assert_json_equal({ 'status' => 'fail', 'reason' => { 'foo' => 'bar' } }, fail('foo' => 'bar'))
  end

  def test_bad_request
    assert_equal [400, "Bad request\n"], bad_request
  end

  def test_not_authorized
    assert_equal [403, "Not authorized\n"], not_authorized
  end

  def test_base_url
    assert_equal 'http://localhost:4567/', base_url
    @base_url = nil
    ENV['RACK_ENV'] = 'production'
    assert_equal 'http://dev.example.com:4567/', base_url
  end

  def test_url_for
    assert_equal 'http://localhost:4567/foo/bar', url_for('foo', 'bar')
  end

end
