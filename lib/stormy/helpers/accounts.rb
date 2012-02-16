# Copyright 2012 Sami Samhuri <sami@samhuri.net>

module Stormy
  module Helpers
    module Accounts

      include Stormy::Models

      def send_reset_password_mail(email)
        if data = Account.reset_password(email)
          body = erb(:'email/reset-password', :layout => :'email/layout', :locals => {
            :name        => data['name'],
            :email       => email,
            :sign_in_url => url_for('sign-in', email, data['token'])
          })
          Pony.mail({
            :to      => email,
            :from    => 'support@example.com',
            :subject => 'Reset your Stormy Weather password',
            :headers => { 'Content-Type' => 'text/html' },
            :body    => body
          })
          data
        end
      end

      def send_verification_mail(account = current_account, subject = nil)
        body = erb(:'email/email-verification', :layout => :'email/layout', :locals => {
          :name  => account.first_name,
          :email => account.email,
          :url   => url_for('account/verify', account.email, account.email_verification_token)
        })
        Pony.mail({
          :to      => account.email,
          :from    => 'support@example.com',
          :subject => subject || 'Verify your Stormy Weather account',
          :headers => { 'Content-Type' => 'text/html' },
          :body    => body
        })
      end

    end
  end
end
