#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class FAQHelperTest < Stormy::Test::HelperCase

  include Stormy::Helpers::FAQ

  def test_faq
    text = faq || ''
    assert_equal '', text
    text = 'new faq'
    self.faq = text
    assert_equal text, faq
  end

end
