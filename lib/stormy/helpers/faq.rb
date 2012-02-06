# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  module Helpers
    module FAQ

      def faq
        redis.get(faq_key)
      end

      def faq=(new_faq)
        redis.set(faq_key, new_faq)
      end

      private

      def faq_key
        @faq_key ||= Stormy.key('faq')
      end

    end
  end
end
