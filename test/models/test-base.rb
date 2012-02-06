#!/usr/bin/env ruby
#
# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'common'

class ModelBaseTest < Stormy::Test::Case

  def setup
    @my_model_class = Class.new(Stormy::Models::Base)
    @my_model_class.class_eval do
      field :id, :required => true
      field :name, :updatable => true, :required => true
      field :age, {
        :type      => :integer,
        :required  => true,
        :updatable => true,
        :validator => proc { |n| n >= 18 }
      }
      field :verified, :type => :boolean

      def create
        self.id = UUID.generate unless id.present?
        super
      end

    end
    @fields = { 'name' => 'Sami', 'age' => '29' }
    @my_model = @my_model_class.create(@fields)
  end

  def teardown
    @my_model_class.list_ids.each { |id| @my_model_class.delete!(id) }
    redis.del(@my_model_class.model_ids_key)
    @my_model_class = nil
  end


  ### Class Methods

  def test_name
    @my_model_class.name 'my_model'
    assert_equal 'my_model', @my_model_class.name
  end

  def test_id_field
    # has id by default
    id_field = {
      :type => :string,
      :required => true
    }
    assert_equal(id_field, @my_model_class.fields[:id])
    methods = %w[id id=]
    methods.each do |name|
      assert @my_model.respond_to?(name)
    end
  end

  def test_name_field
    name_field = {
      :type => :string,
      :required => true,
      :updatable => true
    }
    assert_equal(name_field, @my_model_class.fields[:name])
    methods = %w[name name=]
    methods.each do |name|
      assert @my_model.respond_to?(name)
    end
  end

  def test_age_field
    age_field = {
      :type => :integer,
      :required => true,
      :updatable => true
    }
    age_field.each do |name, value|
      assert_equal value, @my_model_class.fields[:age][name]
    end
    methods = %w[age age=]
    methods.each do |name|
      assert @my_model.respond_to?(name)
    end
  end

  def test_verified_field
    verified_field = { :type => :boolean }
    assert_equal(verified_field, @my_model_class.fields[:verified])
    methods = %w[verified verified= verified?]
    methods.each do |name|
      assert @my_model.respond_to?(name)
    end
  end

  def test_class_create
    assert_equal @fields['name'], @my_model.name
    assert_equal @fields['age'].to_i, @my_model.age
    assert @my_model_class.fetch(@my_model.id)
  end

  def test_class_delete!
    @my_model_class.delete!(@my_model.id)
    assert_nil @my_model_class.fetch(@my_model.id)

    # non-existent objects can be deleted without errors
    @my_model_class.delete!('non-existent id')
  end

  def test_exists?
    assert @my_model_class.exists?(@my_model.id)
    assert !@my_model_class.exists?('non-existent id')
  end

  def test_fetch
    assert @my_model_class.fetch(@my_model.id)
    assert_nil @my_model_class.fetch('non-existent id')
  end

  def test_fetch_all
    objects = @my_model_class.fetch_all
    assert_equal 1, objects.length
    assert_equal @my_model.id, objects.first.id
  end

  def test_key
    id = @my_model.id
    key = Stormy.key(@my_model_class.name, id)
    assert_equal key, @my_model_class.key(id)
  end

  def test_list_ids
    ids = @my_model_class.list_ids
    assert_equal 1, ids.length
    assert_equal @my_model.id, ids.first

    @my_model.delete!
    assert_equal [], @my_model_class.list_ids
  end

  def test_count
    assert_equal 1, @my_model_class.count
    @my_model.delete!
    assert_equal 0, @my_model_class.count
  end


  ### Instance Methods

  def test_initialize
    assert_equal @fields['name'], @my_model.name
    assert_equal @fields['age'].to_i, @my_model.age
    assert !@my_model.verified?
  end

  def test_create
    assert @my_model
    assert @my_model.id.present?

    # indexed
    assert @my_model_class.fetch(@my_model.id)
  end

  def test_delete!
    @my_model.delete!

    assert @my_model_class.fetch(@my_model.id).nil?, 'Object was fetched by id after deletion'

    # indexes
    assert !@my_model_class.exists?(@my_model.id), 'Object exists after deletion'
  end

  def test_reload!
    real_id = @my_model.id
    @my_model.id = 'not my real id'
    @my_model.reload!
    assert_equal real_id, @my_model.id
  end

  def test_update
    original_id = @my_model.id
    updated_id = 'should be ignored'

    @my_model.update('id' => updated_id, 'name' => 'Samson', 'age' => 42, 'verified' => true)
    @my_model.reload!

    # id and verified should not be updated
    assert_equal original_id, @my_model.id
    assert !@my_model.verified?

    # name and age should be updated
    assert_equal 'Samson', @my_model.name
    assert_equal 42, @my_model.age
  end

  def test_update!
    @my_model.update!('age' => -5, :verified => true)
    assert_equal -5, @my_model.age

    # persisted
    @my_model.reload!
    assert_equal -5, @my_model.age
    assert @my_model.verified?
  end

  def test_save
    @my_model.name = 'Samson'
    @my_model.age = 42
    @my_model.save

    # should be persisted
    @my_model.reload!
    assert_equal 'Samson', @my_model.name
    assert_equal 42, @my_model.age
  end

  def test_save!
    @my_model.name = ' '
    @my_model.age = -5
    @my_model.save!
    assert true
  end

  def test_validate
    assert_raises Base::InvalidDataError do
      @my_model.name = ' '
      @my_model.validate
    end

    assert_raises Base::InvalidDataError do
      @my_model.age = -5
      @my_model.validate
    end

    assert_raises Base::InvalidDataError do
      @my_model.age = 0
      @my_model.validate
    end

    assert_raises Base::InvalidDataError do
      @my_model.age = 14
      @my_model.validate
    end

    @my_model.name = 'Samson'
    @my_model.age = 29
    @my_model.validate
  end

end
