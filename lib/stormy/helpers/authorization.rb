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

      def current_project(id = nil)
        if id
          @current_project = Project.fetch(id)
        else
          @current_project
        end
      end

      def project_authorized?
        current_project && current_account && current_project.account_id == current_account.id
      end

      def authorize_project_api!(id)
        authorize_api!
        current_project(id)
        throw(:halt, fail('no such project')) unless current_project
        unless project_authorized?
          content_type 'text/plain'
          throw(:halt, not_authorized)
        end
      end

      def authorize_project!(id)
        authorize!
        current_project(id)
        unless current_project && project_authorized?
          flash[:warning] = 'No such project.'
          redirect '/projects'
        end
      end

      def authorize_admin(id)
        session[:admin_id] = id
      end

      def deauthorize_admin
        session.delete(:admin_id)
      end

      def admin_authorized?
        session[:admin_id] && Models::Admin.exists?(session[:admin_id])
      end

      def admin_authorize!
        unless admin_authorized?
          session[:original_url] = request.url
          redirect '/admin'
        end
      end

      def admin_authorize_api!
        unless admin_authorized?
          content_type 'text/plain'
          throw(:halt, not_authorized)
        end
      end

      def current_admin
        @current_admin ||= Models::Admin.fetch(session[:admin_id])
      end

    end
  end
end
