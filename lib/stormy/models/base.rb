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

      class DuplicateFieldError < RuntimeError
        attr_reader :field
        def initialize(field = nil)
          @field = field
        end
      end

      def self.clean_number(number)
        number.gsub(/[^\d]/, '').sub(/^1/, '')
      end

      # Allows any 10 digit number in North America, or an empty field
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
      def self.model_name(name = nil)
        if name
          @model_name = name
        end
        @model_name
      end


      # Hash of all fields.
      def self.fields
        @fields ||= {}
      end

      def self.inherit_from(parent)
        fields.merge!(parent.fields)
        parent.belongs_to_relationships.each do |key, value|
          belongs_to_relationships[key] = value.dup
        end
        parent.has_many_relationships.each do |key, value|
          has_many_relationships[key] = value.dup
        end
      end

      # Define fields like so:
      #
      #   field :id,        :type => :integer, :required => true
      #   field :name,      :required => true, :updatable => true, :indexed => true
      #   field :email,     :required => true, :updatable => true, :unique => true
      #   field :verified?
      #
      # Defaults: {
      #   :type => :string,
      #   :required => false,
      #   :updatable => false,
      #   :accessors => true,
      #   :validator => nil,     # with some exceptions
      #   :default => {},
      #   :nullify_if_blank => false,
      #   :indexed => false,
      #   :unique => false
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
      # Unless :accessors is false, attribute accessors are
      # defined for each field. Boolean fields get a predicate
      # method as well, e.g. verified?
      #
      # Changed fields are tracked and only changed fields are
      # persisted on a `save`.
      #
      # If the :indexed option is truthy an index on that field
      # will be created and maintained and there will be a class
      # method to fetch objects by that field.
      #
      #   e.g. fetch_by_name(name)
      #
      # If the :unique option is truthy then values for that field
      # must be unique across all instances. This implies :indexed
      # and adds a method to see if a value is taken, to the class
      # and to instances.
      #
      #   e.g. email_taken?(email)
      #
      def self.field(name, options = {})
        if name.to_s.ends_with?('?')
          options[:type] = :boolean
          name = name.to_s[0..-2]
        end

        name = name.to_sym
        options[:type] ||= :string

        unless options.has_key?(:accessors)
          options[:accessors] = true
        end

        if options[:unique]
          options[:indexed] = true
        end

        case options[:type]
        when :email
          options[:validator] = EmailAddressValidator unless options.has_key?(:validator)
          options[:type] = :string
        when :phone
          options[:validator] = PhoneNumberValidator unless options.has_key?(:validator)
          options[:type] = :string
        when :json
          options[:default] = {} unless options.has_key?(:default)
        end

        fields[name] = options

        if options[:accessors]
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
        end # if options[:accessors]

        if options[:indexed]
          index_key_method_name = "#{name}_index_key"
          define_class_method(index_key_method_name) do
            Stormy.key("index:#{model_name}-#{name}")
          end
          define_class_method("fetch_by_#{name}") do |value|
            if id = send("id_from_#{name}", value)
              fetch(id)
            end
          end

          define_class_method("id_from_#{name}") do |value|
            redis.hget(send(index_key_method_name), value.to_s.strip.downcase)
          end
        end

        if options[:unique]
          define_class_method("#{name}_taken?") do |value|
            !! send("id_from_#{name}", value)
          end

          define_method("#{name}_taken?") do |value|
            self.class.send("#{name}_taken?", value)
          end

          define_method("update_#{name}") do |value|
            update_indexed_field(name, value)
          end
        end
      end


      #####################
      ### Relationships ###
      #####################

      def self.has_many_relationships
        @has_many_relationships ||= {}
      end

      def self.has_many(things, options = {})
        thing = things.to_s.singularize
        options[:class_name] ||= thing.capitalize

        has_many_relationships[thing] = options

        define_method("#{thing}_ids_key") do
          ivar_name = "@#{thing}_ids_key"
          unless ids_key = instance_variable_get(ivar_name)
            ids_key = "#{key}:#{thing}-ids"
            instance_variable_set(ivar_name, ids_key)
          end
          ids_key
        end
        private "#{thing}_ids_key"

        define_method("count_#{things}") do
          redis.scard(send("#{thing}_ids_key"))
        end

        define_method("#{thing}_ids") do
          redis.smembers(send("#{thing}_ids_key"))
        end

        define_method(things) do
          klass = Stormy::Models.const_get(options[:class_name])
          send("#{thing}_ids").map { |id| klass.fetch(id) }
        end

        define_method("add_#{thing}_id") do |id|
          redis.sadd(send("#{thing}_ids_key"), id)
        end

        define_method("remove_#{thing}_id") do |id|
          redis.srem(send("#{thing}_ids_key"), id)
        end
      end

      def self.belongs_to_relationships
        @belongs_to_relationships ||= {}
      end

      def self.belongs_to(thing, options = {})
        options[:class_name] ||= thing.to_s.capitalize

        field "#{thing}_id".to_sym, :required => options[:required]

        belongs_to_relationships[thing] = options

        define_method(thing) do
          klass = Stormy::Models.const_get(options[:class_name])
          if thing_id = send("#{thing}_id")
            instance_variable_set("@#{thing}", klass.fetch(thing_id))
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
        # check for unqiue fields
        self.class.fields.each do |name, options|
          if options[:unique] && send("#{name}_taken?", send(name))
            raise DuplicateFieldError.new(name => send(name))
          end
        end

        if has_field?(:id) && field_required?(:id)
          self.id = UUID.generate unless id.present?
        end

        if has_field?(:created_timestamp)
          self.created_timestamp = Time.now.to_i
        end

        # raises if invalid
        save

        add_to_indexes

        self.class.belongs_to_relationships.each do |thing, options|
          if obj = send(thing)
            obj.send("add_#{self.class.model_name}_id", id)
          end
        end

        self
      end

      def delete!
        self.class.has_many_relationships.each do |thing, options|
          klass = Stormy::Models.const_get(options[:class_name])
          send("#{thing}_ids").each { |id| klass.delete!(id) }
        end
        if remove_from_indexes
          self.class.belongs_to_relationships.each do |thing, options|
            if obj = send(thing)
              obj.send("remove_#{self.class.model_name}_id", id)
            end
          end
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

            # ensure uniqueness
            if options[:unique] && send("#{name}_taken?", value)
              raise DuplicateFieldError.new(name => value)
            end
            
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
        if has_field?(:updated_timestamp)
          self.updated_timestamp = Time.now.to_i
        end

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
        # check for invalid fields
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

      def fields
        Hash[field_names.zip(field_names.map { |name| send(name) })]
      end


      private

      def key
        @key ||= self.class.key(self.id)
      end

      def model_name
        @model_name ||= self.class.model_name
      end

      def add_to_indexes
        if redis.sadd(self.class.model_ids_key, id)
          self.class.fields.each do |name, options|
            add_to_field_index(name) if options[:indexed]
          end
        end
      end

      def add_to_field_index(name)
        index_key = self.class.send("#{name}_index_key")
        redis.hset(index_key, send(name).to_s.strip.downcase, id)
      end

      def remove_from_indexes
        if redis.srem(self.class.model_ids_key, id)
          success = true
          self.class.fields.each do |name, options|
            if options[:indexed]
              success = success && remove_from_field_index(name)
            end
            break unless success
          end
          success
        end
      end

      def remove_from_field_index(name)
        index_key = self.class.send("#{name}_index_key")
        redis.hdel(index_key, send(name).to_s.strip.downcase)
      end

      def changed_fields
        @changed_fields ||= {}
      end

      def clean_number(number)
        self.class.clean_number(number)
      end

      def has_field?(name)
        self.class.fields.has_key?(name.to_sym)
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

      def field_required?(name)
        self.class.fields[name.to_sym][:required]
      end

      def field_unique?(name)
        self.class.fields[name.to_sym][:unique]
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

      def update_indexed_field(name, value)
        value = value.strip
        orig = send(name)
        if orig != value
          changed = orig.downcase != value.downcase
          if field_unique?(name) && changed && send("#{name}_taken?", value)
            raise DuplicateFieldError.new(name => value)
          end
          result = validate_field(name, value)
          unless result[:valid]
            raise InvalidDataError.new(name => result[:reason])
          end
          remove_from_field_index(name) if changed
          self.send("#{name}=", value)
          add_to_field_index(name) if changed
          save!
        end
      end

    end
  end
end
