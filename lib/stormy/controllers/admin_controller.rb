# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  class Server < Sinatra::Base

    get '/admin' do
      admin_authorize!
      title "Dashboard"
      erb :'admin/dashboard'
    end


    ################
    ### Accounts ###
    ################

    get '/admin/accounts' do
      admin_authorize!
      mark_last_listing
      title "Accounts"
      @accounts = Account.fetch_all.sort { |a,b| a.name <=> b.name }
      erb :'admin/accounts'
    end

    get '/admin/account/:email' do |email|
      admin_authorize!
      if @account = Account.fetch_by_email(email)
        mark_last_listing
        title "#{@account.name}'s Account"
        script 'admin-account'
        erb :'admin/account'
      else
        flash[:notice] = "No account with email #{email}"
        redirect last_listing
      end
    end

    get '/admin/sign-in-as/:email' do |email|
      admin_authorize!
      authorize_account(Account.id_from_email(email))
      redirect '/account'
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
          rescue Account::DuplicateFieldError => e
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
      erb :'admin/faq'
    end

    post '/admin/faq' do
      admin_authorize!
      self.faq = params['faq']
      flash[:notice] = "FAQ saved."
      redirect '/admin/faq'
    end

  end
end
