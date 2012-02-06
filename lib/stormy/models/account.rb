# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'bcrypt'
require 'uuid'

module Stormy
  module Models
    class Account < Base

      class EmailTakenError < RuntimeError; end
      class IncorrectPasswordError < RuntimeError; end

      name 'account'

      field :id, :required => true

      field :email, :type => :email, :required  => true
      field :first_name, :required => true, :updatable => true
      field :last_name, :required => true, :updatable => true
      field :phone, :type => :phone, :updatable => true

      field :hashed_password, :required => true
      field :password

      field :created_timestamp, :type => :integer
      field :email_verification_token, :nullify_if_blank => true
      field :email_verified?
      field :password_reset_token, :nullify_if_blank => true

      @@account_email_index_key = Stormy.key('index:account-email')


      ### Class Methods

      def self.check_password(email, password)
        id = id_from_email(email)
        key = self.key(id)
        if key
          hashed_password = BCrypt::Password.new(redis.hget(key, 'hashed_password'))
          id if hashed_password == password
        end
      end

      def self.email_taken?(email)
        !! redis.hget(@@account_email_index_key, email.to_s.strip.downcase)
      end

      def self.fetch_by_email(email)
        if id = id_from_email(email)
          fetch(id)
        end
      end

      def self.reset_password(email)
        if key = key_from_email(email)
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

      def self.id_from_email(email)
        redis.hget(@@account_email_index_key, email.strip.downcase)
      end

      def self.verify_email(email, token)
        if key = key_from_email(email)
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
        if key = key_from_email(email)
          redis.hget(key, 'email_verified') == 'true'
        end
      end


      ### Private Class Methods

      def self.key_from_email(email)
        key(id_from_email(email))
      end

      private_class_method :key_from_email


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
        raise EmailTakenError if email_taken?

        # new accounts get an id and timestamp
        self.id = UUID.generate unless id.present?
        self.created_timestamp = Time.now.to_i

        super

        create_email_verification_token

        # add to index
        redis.hset(@@account_email_index_key, email.downcase, id)

        self
      end

      def delete!
        project_ids.each { |id| Project.delete!(id) }
        super
        redis.hdel(@@account_email_index_key, email.strip.downcase)
      end

      def email_taken?(email = @email)
        self.class.email_taken?(email)
      end

      def create_email_verification_token
        self.email_verification_token ||= UUID.generate
        redis.hset(key, 'email_verification_token', email_verification_token)
        email_verification_token
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

      def count_projects
        redis.scard(project_ids_key)
      end

      def project_ids
        redis.smembers(project_ids_key)
      end

      def projects
        project_ids.map { |pid| Project.fetch(pid) }
      end

      def sorted_projects
        @sorted_projects ||= projects.sort { |a,b| a.created_timestamp <=> b.created_timestamp }
      end

      def add_project_id(id)
        redis.sadd(project_ids_key, id)
      end

      def remove_project_id(id)
        redis.srem(project_ids_key, id)
      end

      def update_email(new_email)
        new_email = new_email.strip
        if email != new_email
          raise EmailTakenError if new_email.downcase != email.downcase && email_taken?(new_email)
          raise InvalidDataError.new({ 'email' => 'invalid' }) unless field_valid?('email', new_email)
          if email.downcase != new_email.downcase
            self.email_verified = false
            redis.hdel(@@account_email_index_key, email.downcase)
            redis.hset(@@account_email_index_key, new_email.downcase, id)
          end
          self.email = new_email
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


      private

      def project_ids_key
        @project_ids_key ||= "#{key}:project-ids"
      end

    end
  end
end