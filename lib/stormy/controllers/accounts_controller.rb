# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  class Server < Sinatra::Base

    get '/sign-up' do
      redirect '/projects' if authorized? && production?

      title 'Sign Up'
      stylesheet 'sign-up'
      script 'sign-up'
      @errors = session.delete(:errors) if session[:errors]
      @fields = session.delete(:fields) || {}
      erb :'sign-up'
    end

    post '/sign-up' do
      session.delete('source') if session['source']

      fields = params.slice(*Account.fields.map { |name, options| name.to_s if options[:updatable] }.compact)
      %w[email password].each do |name|
        fields[name] = params[name]
      end

      begin
        @account = Account.create(fields)
        authorize_account(@account.id)
        send_verification_mail(@account, 'Welcome to Stormy Weather!')
        redirect '/projects'

      rescue Account::EmailTakenError => e
        flash[:warning] = "That email address is already taken."
        session[:fields] = fields
        session[:fields]['terms'] = params['terms']
        session[:errors] = { 'email' => 'taken' }
        redirect '/sign-up'

      rescue Account::InvalidDataError => e
        flash[:warning] = "There's a small problem with your info."
        session[:fields] = fields
        session[:fields]['terms'] = params['terms']
        session[:errors] = e.fields
        if session[:errors].has_key?('hashed_password')
          session[:errors]['password'] = session[:errors].delete('hashed_password')
        end
        redirect '/sign-up'
      end
    end

    get '/sign-in' do
      redirect '/projects' if authorized? && production?

      title 'Sign In'
      stylesheet 'sign-in'
      script 'sign-in'
      @email = session.delete(:email)
      erb :'sign-in'
    end

    post '/sign-in' do
      if id = Account.check_password(params['email'], params['password'])
        authorize_account(id)
        if params['remember'] == 'on'
          response.set_cookie('remembered', {
            :value => current_account.id,
            :path => '/',
            :expires => Time.now + 2.weeks,
            :httponly => true
          })
        else
          response.delete_cookie('remembered')
        end
        url = session.delete(:original_url) || '/projects'
        redirect url
      else
        flash[:warning] = "Incorrect email address or password."
        redirect '/sign-in'
      end
    end

    post '/sign-out' do
      deauthorize
      redirect '/'
    end

    get '/forgot-password/?:email?' do |email|
      title 'Forgot Password'
      script 'forgot-password'
      @email = email
      erb :'forgot-password'
    end

    post '/forgot-password' do
      if params['email'].blank?
        flash[:warning] = "Enter your email address so we can send you a link to reset your password."
        redirect '/forgot-password'
      elsif send_reset_password_mail(params['email'])
        flash[:notice] = "A link to reset your password was sent to #{escape_html(params['email'])}."
        redirect '/sign-in'
      else
        flash[:warning] = "We don't have an account for #{escape_html(params['email'])}."
        redirect '/forgot-password'
      end
    end

    # reset password
    get '/sign-in/:email/:token' do |email, token|
      if id = Account.use_password_reset_token(email, token)
        authorize_account(id)
        title 'Reset My Password'
        stylesheet 'reset-password'
        script 'reset-password'
        erb :'reset-password'
      else
        flash[:warning] = "Unknown or expired link to reset password."
        redirect '/forgot-password/' + email
      end
    end

    post '/account/reset-password' do
      authorize!
      current_account.password = params['password']
      current_account.save!
      redirect '/projects'
    end

    get '/account' do
      authorize!
      title 'Account'
      stylesheet 'account'
      script 'jquery.jeditable'
      script 'account'
      script 'account-editable'
      @account = current_account
      erb :account
    end

    post '/account/password' do
      content_type :json
      authorize_api!

      begin
        raise Account::InvalidDataError unless params['new-password'] == params['password-confirmation']
        current_account.update_password(params['old-password'], params['new-password'])
        ok
      rescue Account::IncorrectPasswordError => e
        fail('incorrect')
      rescue Account::InvalidDataError => e
        fail('invalid')
      end
    end

    post '/account/update' do
      authorize_api!

      begin
        current_account.update({ params['id'] => params['value'] })
        params['value']
      rescue Account::InvalidDataError => e
        # This is lame but gives the desired result with jEditable
        bad_request
      end
    end

    post '/account/update.json' do
      content_type :json
      authorize_api!

      begin
        if params['id'] == 'email'
          old_email = current_account.email
          new_email = params['value']
          current_account.update_email(new_email)
          if old_email.downcase != new_email.downcase
            send_verification_mail unless current_account.email_verified?
          end
        else
          # decode booleans
          if params['id'].match(/_notifications$/)
            if params['value'] == 'true'
              params['value'] = true
            elsif params['value'] == 'false'
              params['value'] = false
            end
          end
          current_account.update({ params['id'] => params['value'] })
        end
        ok
      rescue Account::EmailTakenError => e
        fail('taken')
      rescue Account::InvalidDataError => e
        fail('invalid')
      end
    end


    ####################
    ### Verification ###
    ####################

    get '/account/verify/:email/:token' do |email, token|
      if Account.verify_email(email, token)
        authorize_account(Account.id_from_email(email)) unless authorized?
        flash[:notice] = "Your email address has been verified."
        redirect '/account'
      elsif authorized?
        redirect '/account'
      else
        erb :'verification-failed'
      end
    end

    post '/account/send-email-verification' do
      content_type :json
      authorize_api!
      send_verification_mail
      ok
    end

  end
end
