# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'rdiscount'

module Stormy
  module Helpers
    module Views

      def escape_html(s)
        Rack::Utils::escape_html(s)
      end

      def script(name)
        if name.match(/^(https?:)?\/\//)
          scripts << name
        elsif production?
          scripts << "/js-min/#{name}.js"
        else
          scripts << "/js/#{name}.js"
        end
      end

      def scripts
        @page_scripts ||= [
          '//ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js',
          "/js#{production? ? '-min' : ''}/jquery.placeholder.js",
          "/js#{production? ? '-min' : ''}/common.js"
        ]
      end

      def stylesheet(name)
        if production?
          stylesheets << "/css-min/#{name}.css"
        else
          stylesheets << "/css/#{name}.css"
        end
      end

      def stylesheets
        @page_styles ||= ["/css#{production? ? '-min' : ''}/common.css"]
      end

      def title(title = nil)
        @page_title = title if title
        @page_title
      end

      def flash_message
        if flash[:notice]
          klass = 'notice'
          message = flash[:notice]
        elsif flash[:warning]
          klass = 'warning'
          message = flash[:warning]
        elsif flash[:error]
          klass = 'error'
          message = flash[:error]
        else
          klass = flash.keys.first
          message = flash[klass] if klass
        end
        if message
          "<div id=\"flash\" class=\"#{klass}\">#{message}</div>"
        end
      end

      def breadcrumbs
        @breadcrumbs ||= []
      end

      def breadcrumb(crumb)
        crumb[:path] ||= '/' + crumb[:name].downcase
        breadcrumbs << crumb
      end

      def format_dollars(amount, currency = 'CAD')
        '%s $%.2f' % [currency, amount / 100.0]
      end

      def format_date(date)
        date.strftime("%B %e, %Y")
      end

      def format_time(time)
        time.strftime('%B %e, %Y %l:%M %p')
      end

      def pad(n)
        n < 10 ? "0#{n}" : "#{n}"
      end

      def format_duration(duration)
        mins = duration / 60
        secs = duration % 60
        "#{pad(mins)}:#{pad(secs)}"
      end

      def ordinal_day(day)
        th = case day
             when 1
               'st'
             when 2
               'nd'
             when 3
               'rd'
             when 21
               'st'
             when 22
               'nd'
             when 23
               'rd'
             when 31
               'st'
             else
               'th'
             end
        "#{day}#{th}"
      end

      def format_percent(percent)
        "#{(100 * percent).to_i}%"
      end

      def markdown(s)
        RDiscount.new(s.to_s).to_html
      end

      def admin_page?(path = request.path_info)
        path.starts_with?('/admin')
      end

    end
  end
end
