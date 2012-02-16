# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  module Helpers
    module Admin

      include Stormy::Models

      def num_accounts
        Account.count
      end

      # Used to redirect back to the most recent list of things.
      #
      # i.e. someone goes to /admin -> /admin/account/foo -> /admin/thing/007
      #      if they delete that thing they should go back to /admin/account/foo
      #
      #      however if they go /admin -> /admin/things -> /admin/thing/007
      #      and then delete that thing they should go back to /admin/things
      def last_listing
        session.delete(:last_listing) || '/admin'
      end

      def mark_last_listing(path = request.path_info)
        session[:last_listing] = path
      end

    end
  end
end
