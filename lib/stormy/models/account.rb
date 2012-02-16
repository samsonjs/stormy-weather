# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'bcrypt'
require 'uuid'

module Stormy
  module Models
    class Account < Base

      class IncorrectPasswordError < RuntimeError; end

      Roles = %w[user admin]

      model_name 'account'

      field :id, :required => true

      field :email, :type => :email, :required  => true, :unique => true
      field :first_name, :required => true, :updatable => true
      field :last_name, :required => true, :updatable => true
      field :phone, :type => :phone, :updatable => true

      field :created_timestamp, :type => :integer
      field :email_verification_token, :nullify_if_blank => true
      field :email_verified?
      field :hashed_password, :required => true
      field :password
      field :password_reset_token, :nullify_if_blank => true
      field :role, :required => true


      ### Class Methods

      def self.check_password(email, password)
        id = id_from_email(email)
        key = self.key(id)
        if key
          hashed_password = BCrypt::Password.new(redis.hget(key, 'hashed_password'))
          id if hashed_password == password
        end
      end

      def self.reset_password(email)
        if key = key(id_from_email(email))
          token = redis.hget(key, 'password_reset_token')
          if token.blank?
            token = UUID.generate
            redis.hset(key, 'password_reset_token', token)
          end
          { 'name' => redis.hget(key, 'first_name'),
            'token' => token
          }
        end
      end

      def self.use_password_reset_token(email, token)
        if id = id_from_email(email)
          key = key(id)
          expected_token = redis.hget(key, 'password_reset_token')
          if token == expected_token
            redis.hdel(key, 'password_reset_token')
            id
          end
        end
      end

      def self.verify_email(email, token)
        if key = key(id_from_email(email))
          expected_token = redis.hget(key, 'email_verification_token')
          verified = token == expected_token
          if verified
            redis.hdel(key, 'email_verification_token')
            redis.hset(key, 'email_verified', true)
          end
          verified
        end
      end

      def self.email_verified?(email)
        if key = key(id_from_email(email))
          redis.hget(key, 'email_verified') == 'true'
        end
      end


      ### Instance Methods

      def initialize(fields = {}, options = {})
        super(fields, options)

        if fields['hashed_password']
          self.hashed_password = BCrypt::Password.new(fields['hashed_password'])
        else
          self.password = fields['password']
        end
      end

      def create
        self.role = 'user' if role.blank?
        super
      end

      def has_role?(role)
        Roles.index(self.role) >= Roles.index(role)
      end

      def email_verification_token
        unless @email_verification_token
          @email_verification_token = UUID.generate
          redis.hset(key, 'email_verification_token', @email_verification_token)
        end
        @email_verification_token
      end

      def password
        @password ||= BCrypt::Password.new(hashed_password)
      end

      def password=(new_password)
        if new_password.present?
          self.hashed_password = BCrypt::Password.create(new_password)
          @password = nil
        end
      end

      def name
        "#{first_name} #{last_name}"
      end

      def update_email(new_email)
        new_email = new_email.strip
        if email != new_email
          changed = new_email.downcase != email.downcase
          raise DuplicateFieldError.new(:email => new_email) if changed && email_taken?(new_email)
          raise InvalidDataError.new('email' => 'invalid') unless field_valid?('email', new_email)
          self.email_verified = false if changed
          remove_from_field_index(:email) if changed
          self.email = new_email
          add_to_field_index(:email) if changed
          save!
        end
      end

      def update_password(old_password, new_password)
        hashed_password = BCrypt::Password.new(redis.hget(key, 'hashed_password'))
        raise IncorrectPasswordError unless hashed_password == old_password
        raise InvalidDataError.new({ 'password' => 'missing' }) if new_password.blank?
        redis.hset(key, 'hashed_password', BCrypt::Password.create(new_password))
        self.password = new_password
      end

    end
  end
end