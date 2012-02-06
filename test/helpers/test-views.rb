#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class ViewsHelperTest < Stormy::Test::HelperCase

  include Stormy::Helpers::Views

  def teardown
    @page_scripts = nil
    @page_styles = nil
    @page_title = nil
    @flash = nil
    ENV['RACK_ENV'] = 'test'
  end

  def flash
    @flash ||= {}
  end


  def test_escape_html
    assert_equal 'plain text', escape_html('plain text')
    assert_equal '&lt;not a tag&gt;', escape_html('<not a tag>')
    assert_equal 'this &amp; that', escape_html('this & that')
    assert_equal 'https:&#x2F;&#x2F;example.com', escape_html('https://example.com')
  end

  def test_script_absolute
    expected_scripts = [
      '//ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js',
      '/js/jquery.placeholder.js',
      '/js/common.js'
    ]
    assert_equal expected_scripts, scripts

    script '//foo.ca/bar.js'
    expected_scripts << '//foo.ca/bar.js'
    assert_equal expected_scripts, scripts

    script 'http://foo.ca/bar.js'
    expected_scripts << 'http://foo.ca/bar.js'
    assert_equal expected_scripts, scripts

    script 'https://foo.ca/bar.js'
    expected_scripts << 'https://foo.ca/bar.js'
    assert_equal expected_scripts, scripts
  end

  def test_script_relative
    expected_scripts = [
      '//ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js',
      '/js/jquery.placeholder.js',
      '/js/common.js'
    ]
    assert_equal expected_scripts, scripts
    script 'foo'
    assert_equal expected_scripts + ['/js/foo.js'], scripts
  end

  def test_script_minified
    ENV['RACK_ENV'] = 'production'
    expected_scripts = [
      '//ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js',
      '/js-min/jquery.placeholder.js',
      '/js-min/common.js'
    ]
    assert_equal expected_scripts, scripts
    script 'foo'
    assert_equal expected_scripts + ['/js-min/foo.js'], scripts
  end

  def test_scripts
    expected_scripts = [
      '//ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js',
      '/js/jquery.placeholder.js',
      '/js/common.js'
    ]
    assert_equal expected_scripts, scripts
    scripts << 'foo'
    assert_equal expected_scripts + ['foo'], scripts
  end

  def test_stylesheet_relative
    assert_equal ['/css/common.css'], stylesheets
    stylesheet 'foo'
    assert_equal ['/css/common.css', '/css/foo.css'], stylesheets
  end

  def test_stylesheet_minified
    ENV['RACK_ENV'] = 'production'
    assert_equal ['/css-min/common.css'], stylesheets
    stylesheet 'foo'
    assert_equal ['/css-min/common.css', '/css-min/foo.css'], stylesheets
  end

  def test_stylesheets
    assert_equal ['/css/common.css'], stylesheets
    stylesheets << 'stylesheet'
    assert_equal ['/css/common.css', 'stylesheet'], stylesheets
  end

  def test_title
    title 'my title'
    assert_equal 'my title', title
  end

  def test_flash_notice
    flash[:notice] = 'bar &amp; baz'
    expected_html = '<div id="flash" class="notice">bar &amp; baz</div>'
    assert_equal expected_html, flash_message
  end

  def test_flash_warning
    flash[:warning] = 'bar &amp; baz'
    expected_html = '<div id="flash" class="warning">bar &amp; baz</div>'
    assert_equal expected_html, flash_message
  end

  def test_flash_error
    flash[:error] = 'bar &amp; baz'
    expected_html = '<div id="flash" class="error">bar &amp; baz</div>'
    assert_equal expected_html, flash_message
  end

  def test_flash_unknown
    flash[:foo] = 'bar &amp; baz'
    expected_html = '<div id="flash" class="foo">bar &amp; baz</div>'
    assert_equal expected_html, flash_message

    # the first key is used for unknown types, so :foo still wins and the expected output is unchanged
    flash[:quux] = 'bar &amp; baz'
    assert_equal expected_html, flash_message
  end

  def test_flash_empty
    assert_nil flash_message
  end

  def test_format_dollars
    assert_equal 'CAD $0.00', format_dollars(0)
    assert_equal 'CAD $0.99', format_dollars(99)
    assert_equal 'CAD $1.00', format_dollars(100)
    assert_equal 'CAD $1.01', format_dollars(101)
    assert_equal 'CAD $10.00', format_dollars(1000)

    assert_equal 'USD $10.00', format_dollars(1000, 'USD')
  end

  def test_format_date
    time = Time.new(2012, 1, 9, 4, 36, 36)
    assert_equal 'January  9, 2012', format_date(time)
  end

  def test_format_time
    time = Time.new(2012, 1, 9, 14, 36, 36)
    assert_equal 'January  9, 2012  2:36 PM', format_time(time)
  end

  def test_format_duration
    assert_equal '00:00', format_duration(0)
    assert_equal '00:30', format_duration(30)
    assert_equal '01:00', format_duration(60)
    assert_equal '01:01', format_duration(61)
    assert_equal '01:30', format_duration(90)
    assert_equal '02:00', format_duration(120)
    assert_equal '02:01', format_duration(121)
    assert_equal '99:59', format_duration(5999)
    assert_equal '100:00', format_duration(6000)
  end

  def test_ordinal_day
    assert_equal '1st', ordinal_day(1)
    assert_equal '2nd', ordinal_day(2)
    assert_equal '3rd', ordinal_day(3)
    assert_equal '4th', ordinal_day(4)
    assert_equal '11th', ordinal_day(11)
    assert_equal '12th', ordinal_day(12)
    assert_equal '13th', ordinal_day(13)
    assert_equal '14th', ordinal_day(14)
    assert_equal '21st', ordinal_day(21)
    assert_equal '22nd', ordinal_day(22)
    assert_equal '23rd', ordinal_day(23)
    assert_equal '24th', ordinal_day(24)
    assert_equal '31st', ordinal_day(31)
  end

  def test_format_percent
    assert_equal '0%', format_percent(0)
    assert_equal '10%', format_percent(0.1)
    assert_equal '100%', format_percent(1.0)
  end

  def test_markdown
    expected_html = "<p>this is <em>some</em> markdown</p>\n"
    assert_equal expected_html, markdown('this is *some* markdown')
  end

  def test_markdown_is_resilient
    assert_equal "\n", markdown(nil)
    assert_equal "<p>42</p>\n", markdown(42)
  end

end
