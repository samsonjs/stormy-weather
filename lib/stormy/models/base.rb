# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'json'
require 'redis'
require 'uuid'

module Stormy
  module Models
    class Base

      class InvalidDataError < RuntimeError
        attr_reader :fields
        def initialize(invalid_fields = {})
          @fields = invalid_fields
        end
      end

      def self.clean_number(number)
        number.gsub(/[^\d]/, '').sub(/^1/, '')
      end

      # Allows any 10 digit number in North America, or an empty field (for account creation).
      PhoneNumberValidator = proc do |number|
        if number.present?
          clean_number(number).length == 10
        else
          true
        end
      end

      # Liberal email address regex
      EmailAddressValidator = proc { |email| email =~ /^[^@]+@[^.@]+(\.[^.@]+)+$/ }


      # Only changed fields are persisted on save
      attr_reader :changed_fields


      #####################
      ### Class Methods ###
      #####################

      @@redis = Redis.new

      def self.redis
        @@redis
      end


      # Define or retrieve the name of this model.
      def self.name(name = nil)
        if name
          @model_name = name
        end
        @model_name
      end


      # Hash of all fields.
      def self.fields
        @fields ||= {}
      end


      # Define fields like so:
      #
      #   field :id,        :type => :integer, :required => true
      #   field :name,      :required => true, :updatable => true
      #   field :verified?
      #
      # Defaults: {
      #   :type => :string,
      #   :required => false,
      #   :updatable => false,
      #   :validator => nil,     # with some exceptions
      #   :default => {},
      #   :nullify_if_blank => false
      # }
      #
      # Types: :string, :integer, :boolean, :json, as well as
      # :email and :phone which are string aliases with the
      # appropriate validations. String fields have an option
      # :nullify_if_blank that will initialize and set fields
      # to `nil` if they are empty.
      #
      # If an `integer` is required it must be greater than zero.
      # The required option has no effect on boolean fields.
      #
      # Fields with names ending with question mark are boolean.
      #
      # JSON fields accept a :default option used to initialize
      # a JSON field, and also when a parse fails.
      #
      # Attribute accessors are defined for each field and boolean
      # fields get a predicate method as well, e.g. verified?
      #
      # Changed fields are tracked and only changed fields are
      # persisted on a `save`.
      #
      def self.field(name, options = {})
        if name.to_s.ends_with?('?')
          options[:type] = :boolean
          name = name.to_s[0..-2]
        end

        name = name.to_sym
        options[:type] ||= :string

        case options[:type]
        when :email
          options[:validator] ||= EmailAddressValidator
          options[:type] = :string
        when :phone
          options[:validator] ||= PhoneNumberValidator
          options[:type] = :string
        when :json
          options[:default] ||= {}
        end

        fields[name] = options
        define_method(name) do
          instance_variable_get("@#{name}")
        end

        case options[:type]
        when :string
          define_method("#{name}=") do |value|
            s =
              if options[:nullify_if_blank] && value.blank?
                nil
              else
                value.to_s.strip
              end
            instance_variable_set("@#{name}", s)
            changed_fields[name] = s
          end

        when :integer
          define_method("#{name}=") do |value|
            i = value.to_i
            instance_variable_set("@#{name}", i)
            changed_fields[name] = i
          end

        when :boolean
          define_method("#{name}=") do |value|
            b = value == 'true' || value == true
            instance_variable_set("@#{name}", b)
            changed_fields[name] = b
          end
          define_method("#{name}?") do
            instance_variable_get("@#{name}")
          end

        when :json
          define_method(name) do
            unless value = instance_variable_get("@#{name}")
              value = options[:default].dup
              send("#{name}=", value)
            end
            value
          end
          define_method("#{name}=") do |value|
            obj =
              if value.is_a?(String)
                if value.length > 0
                  JSON.parse(value)
                else
                  options[:default].dup
                end
              else
                value
              end
            instance_variable_set("@#{name}", obj)
            changed_fields[name] = obj
          end

        else
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value)
            changed_fields[name] = value
          end
        end
      end


      # internal
      def self.model_ids_key
        @model_ids_key ||= Stormy.key("#{@model_name}-ids")
      end


      def self.create(fields = {})
        new(fields).create
      end

      def self.delete!(id)
        if obj = fetch(id)
          obj.delete!
        end
      end

      def self.exists?(id)
        redis.sismember(model_ids_key, id)
      end

      def self.fetch(id)
        if id && exists?(id)
          new(redis.hgetall(key(id)), :fetched => true)
        end
      end

      def self.fetch_all
        list_ids.map { |id| fetch(id) }
      end

      def self.key(id)
        Stormy.key(@model_name, id) if id
      end

      def self.list_ids
        redis.smembers(model_ids_key)
      end

      def self.count
        redis.scard(model_ids_key)
      end


      ### Instance Methods

      attr_accessor :redis

      def initialize(fields = {}, options = {})
        self.redis = self.class.redis

        fields = fields.symbolize_keys
        field_names.each do |name|
          send("#{name}=", fields[name])
        end

        # no changed fields yet if we have been fetched
        if options[:fetched]
          @changed_fields = {}
        end
      end

      def create
        # raises if invalid
        save
        add_to_index
        self
      end

      def delete!
        if redis.srem(self.class.model_ids_key, id)
          redis.del(key)
        end
      end

      def reload!
        initialize(redis.hgetall(key))
        self
      end

      # Convenient defaults for performing safe updates.
      def update!(fields, options = {})
        options[:validate] = false unless options.has_key?(:validate)
        options[:all] = true unless options.has_key?(:all)
        update(fields, options)
      end

      # The `update` method only updates fields marked updatable.
      # Unless you pass in :all => true, then all fields are
      # updated.
      #
      # There's also a :validate flag.
      #
      def update(fields, options = {})
        options[:validate] = true unless options.has_key?(:validate)
        fields.each do |name, value|
          if options[:all] || field_updatable?(name)
            send("#{name}=", value)
          end
        end
        if options[:validate]
          save
        else
          save!
        end
      end

      def save
        validate
        save!
      end

      def save!
        # always update JSON fields because they can be updated without our knowledge
        field_names.each do |name|
          if field_type(name) == :json
            changed_fields[name] = send(name)
          end
        end

        fields = changed_fields.map do |name, value|
          if field_type(name) == :json && !value.is_a?(String)
            [name, JSON.fast_generate(value || field_default(name))]
          else
            [name, value]
          end
        end
        if fields.length > 0
          redis.hmset(key, *fields.flatten)
        end
        @changed_fields = {}
      end

      def validate
        invalid_fields = field_names.inject({}) do |fields, name|
          if field_validates?(name)
            result = validate_field(name, send(name))
            fields[name] = result[:reason] unless result[:valid]
          end
          fields
        end
        if invalid_fields.length > 0
          raise InvalidDataError.new(invalid_fields.stringify_keys)
        end
      end


      private

      def key
        @key ||= self.class.key(self.id)
      end

      def add_to_index
        redis.sadd(self.class.model_ids_key, self.id)
      end

      def changed_fields
        @changed_fields ||= {}
      end

      def clean_number(number)
        self.class.clean_number(number)
      end

      def field_names
        self.class.fields.keys
      end

      def field_type(name)
        self.class.fields[name.to_sym][:type]
      end

      def field_updatable?(name)
        self.class.fields[name.to_sym][:updatable]
      end

      def validate_field(name, value)
        valid = true
        reason = nil
        field = self.class.fields[name.to_sym]
        type = field[:type]
        if field[:required]
          case
          when type == :string && value.blank?
            valid = false
            reason = 'missing'
          when type == :integer && value.to_i <= 0
            valid = false
            reason = 'missing'
          when type == :json && value.blank?
            valid = false
            reason = 'missing'
          end
        end
        if valid && validator = field[:validator]
          valid = validator.call(value)
          reason = 'invalid'
        end
        { :valid => valid, :reason => reason }
      end

      def field_valid?(name, value)
        result = validate_field(name, value)
        result[:valid]
      end

      def field_validates?(name)
        field = self.class.fields[name.to_sym]
        field[:required] || field[:validator]
      end

      def field_default(name)
        self.class.fields[name][:default]
      end

    end
  end
end
