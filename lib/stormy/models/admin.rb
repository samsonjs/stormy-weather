# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'bcrypt'
require 'uuid'

module Stormy
  module Models
    class Admin < Base

      class EmailTakenError < RuntimeError; end
      class IncorrectPasswordError < RuntimeError; end

      name 'admin'

      field :id, :required => true

      field :name, :required => true, :updatable => true
      field :email, :type => :email, :required => true
      field :hashed_password, :required => true
      field :password

      @@admin_email_index_key = Stormy.key('index:admin-email')


      ### Class Methods

      def self.key_from_email(email)
        key(id_from_email(email))
      end

      def self.check_password(email, password)
        id = id_from_email(email)
        key = self.key(id)
        if key
          hashed_password = BCrypt::Password.new(redis.hget(key, 'hashed_password'))
          id if hashed_password == password
        end
      end

      def self.email_taken?(email)
        !! redis.hget(@@admin_email_index_key, email.to_s.strip.downcase)
      end

      def self.fetch_by_email(email)
        key = key_from_email(email)
        new(redis.hgetall(key)) if key
      end

      def self.id_from_email(email)
        redis.hget(@@admin_email_index_key, email.strip.downcase)
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
        raise EmailTakenError if email_taken?

        self.id = UUID.generate unless id.present?

        super

        # add to index
        redis.hset(@@admin_email_index_key, @email.downcase, @id)

        self
      end

      def delete!
        if super
          redis.hdel(@@admin_email_index_key, @email.strip.downcase)
        end
      end

      def email_taken?(email = @email)
        self.class.email_taken?(email)
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

      def update_email(new_email)
        new_email = new_email.strip
        if email != new_email
          raise EmailTakenError if new_email.downcase != email.downcase && email_taken?(new_email)
          raise InvalidDataError.new({ 'email' => 'invalid' }) unless field_valid?('email', new_email)
          if email.downcase != new_email.downcase
            redis.hdel(@@admin_email_index_key, email.downcase)
            redis.hset(@@admin_email_index_key, new_email.downcase, id)
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

    end
  end
end