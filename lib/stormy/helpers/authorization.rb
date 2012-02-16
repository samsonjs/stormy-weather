# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  module Helpers
    module Authorization

      include Stormy::Models

      def authorize_account(id)
        session[:id] = id
      end

      def authorized?
        if !session[:id] && id = request.cookies['remembered']
          authorize_account(id)
        end
        session[:id] && Account.exists?(session[:id])
      end

      def authorize!
        unless authorized?
          session[:original_url] = request.url
          redirect '/sign-in'
        end
      end

      def authorize_api!
        unless authorized?
          content_type 'text/plain'
          throw(:halt, not_authorized)
        end
      end

      def deauthorize
        session.delete(:id)
        response.delete_cookie('remembered')
      end

      def current_account
        if session[:id]
          @current_account ||= Account.fetch(session[:id])
        end
      end

      def admin_authorized?
        authorized? && current_account.has_role?('admin')
      end

      def admin_authorize!
        unless admin_authorized?
          session[:original_url] = request.url
          redirect '/sign-in'
        end
      end

      def admin_authorize_api!
        unless admin_authorized?
          content_type 'text/plain'
          throw(:halt, not_authorized)
        end
      end

    end
  end
end
