# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  class Server < Sinatra::Base

    get '/admin' do
      admin_authorize!
      title "Dashboard"
      erb :'admin/dashboard', :layout => :'admin/layout'
    end

    get '/admin/sign-in' do
      title "Sign In"
      script 'sign-in'
      stylesheet 'sign-in'
      erb :'admin/sign-in', :layout => :'admin/layout'
    end

    post '/admin/sign-in' do
      if id = Admin.check_password(params['email'], params['password'])
        authorize_admin(id)
        redirect session.delete(:original_url) || '/admin'
      else
        flash[:notice] = "Incorrect email address or password."
        redirect '/admin/sign-in'
      end
    end

    post '/admin/sign-out' do
      session.delete(:admin_id)
      redirect '/admin'
    end

    get '/admin/password' do
      admin_authorize!
      title 'Change password'
      erb :'admin/password', :layout => :'admin/layout'
    end

    post '/admin/password' do
      admin_authorize!
      if params['password'] == params['password_confirmation']
        current_admin.password = params['password']
        current_admin.save
        flash[:notice] = "Password changed."
        redirect '/admin'
      else
        flash[:warning] = "Passwords do not match."
        redirect '/admin/password'
      end
    end


    ################
    ### Accounts ###
    ################

    get '/admin/accounts' do
      admin_authorize!
      mark_last_listing
      title "Accounts"
      @accounts = Account.fetch_all.sort { |a,b| a.name <=> b.name }
      erb :'admin/accounts', :layout => :'admin/layout'
    end

    get '/admin/account/:email' do |email|
      admin_authorize!
      if @account = Account.fetch_by_email(email)
        mark_last_listing
        title "#{@account.name}'s Account"
        script 'admin-account'
        erb :'admin/account', :layout => :'admin/layout'
      else
        flash[:notice] = "No account with email #{email}"
        redirect last_listing
      end
    end

    get '/admin/sign-in-as/:email' do |email|
      admin_authorize!
      authorize_account(Account.id_from_email(email))
      redirect '/projects'
    end

    get '/admin/account/:email/delete' do |email|
      admin_authorize!
      if @account = Account.fetch_by_email(email)
        @account.delete!
      end
      redirect last_listing
    end

    post '/admin/account/:email' do |email|
      admin_authorize!
      if @account = Account.fetch_by_email(email)
        email_changed = params['new_email'].present? && params['new_email'] != @account.email
        fields = params.merge({
          'email_verified' => email_changed ? true : @account.email_verified
        })
        fields.delete('splat')
        fields.delete('captures')
        fields.delete('email')
        new_email = fields.delete('new_email')
        new_email = @account.email if new_email.blank?
        if new_email != @account.email
          begin
            @account.update_email(new_email)
          rescue Account::EmailTakenError => e
            flash[:warning] = "That email address is already taken."
            redirect '/admin/account/' + email
          end
        end
        begin
          @account.update!(fields, :validate => true)
          flash[:notice] = "Account updated."
        rescue Account::InvalidDataError => e
          flash[:warning] = "Invalid fields: #{e.fields.inspect}"
        end
        redirect '/admin/account/' + new_email
      else
        flash[:notice] = "No account with email #{email}"
        redirect last_listing
      end
    end


    ################
    ### Projects ###
    ################

    get '/admin/projects' do
      admin_authorize!
      mark_last_listing
      title "Projects"
      @projects = Project.fetch_all.sort { |a,b| a.id <=> b.id }
      erb :'admin/projects', :layout => :'admin/layout'
    end

    get '/admin/project/:id' do |id|
      admin_authorize!
      if @project = Project.fetch(id)
        title "Project ##{id}"
        title "#{title} (#{@project.name})" if @project.name
        script 'admin-project'
        erb :'admin/project', :layout => :'admin/layout'
      else
        flash[:notice] = "No such project (ID #{id})."
        redirect last_listing
      end
    end

    get '/admin/project/:id/delete' do |id|
      admin_authorize!
      Project.delete!(id)
      redirect last_listing
    end


    ###########
    ### FAQ ###
    ###########

    get '/admin/faq' do
      admin_authorize!
      title 'FAQ'
      @faq = faq
      if @faq.blank?
        @faq = <<-EOT
<p class="question">1. Are you my mother?</p>
<p class="answer">Yes my son.</p>
        EOT
      end
      erb :'admin/faq', :layout => :'admin/layout'
    end

    post '/admin/faq' do
      admin_authorize!
      self.faq = params['faq']
      flash[:notice] = "FAQ saved."
      redirect '/admin/faq'
    end


    ######################
    ### Admin Accounts ###
    ######################

    get '/admin/admins' do
      admin_authorize!
      @admins = Admin.fetch_all.sort { |a,b| a.name <=> b.name }
      @fields = session.delete(:fields) || {}
      title 'Admin Accounts'
      stylesheet 'admins'
      erb :'admin/admins', :layout => :'admin/layout'
    end

    post '/admin/admins' do
      admin_authorize!
      if params['password'] == params['password_confirmation']
        admin = Admin.create(params)
        flash[:notice] = "Added #{params['name']} (#{params['email']}) as an admin."
      else
        session[:fields] = params.slice('name', 'email')
        flash[:warning] = "Passwords do not match."
      end
      redirect '/admin/admins'
    end

    get '/admin/admins/:id/delete' do |id|
      admin_authorize!
      Admin.delete!(id)
      flash[:notice] = "Deleted."
      redirect '/admin/admins'
    end

  end
end
