#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class ConfigTest < Stormy::Test::Case

  def setup
    @config ||= Stormy::Config.instance
  end

  def defaults
    @defaults ||= Stormy::Config::DefaultConfig
  end

  def test_initialize_stores_defaults_if_empty
    if defaults.length > 0
      assert redis.exists(@config.config_key)
      defaults.each do |name, value|
        assert_equal defaults[name], @config.send(name), name
      end
    end
  end

  def test_reload_decodes_values
  end

  def test_method_missing_set
    # existing value
    # (none yet)

    # new value
    @config.foo = 42
    assert_equal 42, @config.foo
    @config.config.delete('foo')
  end

  def test_method_missing_get
    # (none yet)
    # assert_equal defaults['foo_bar'], @config.foo_bar
  end

  def test_method_missing_get_default
    defaults['new_config_option'] = 42
    assert_equal 42, @config.new_config_option
    defaults.delete('new_config_option')
    @config.config.delete('new_config_option')
  end

  def test_method_missing_super
    assert_raises NoMethodError do
      @config.non_existent_option
    end
  end

end
