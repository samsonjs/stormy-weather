#!/usr/bin/env ruby
#
# Copyright 2011 Beta Street Media

require 'common'

JPEGHeader = "\xFF\xD8\xFF\xE0\u0000\u0010JFIF"

class ProjectTest < Stormy::Test::Case

  include Stormy::Test::Helpers::Accounts
  include Stormy::Test::Helpers::Projects

  def setup
    setup_accounts
    setup_projects
    @test_photo_path = photo_file('wild-wacky-action-bike.jpg')
  end

  def teardown
    teardown_projects
    teardown_accounts
  end

  def check_project_fields(project, fields)
    fields.each do |key, expected|
      actual = project.send(key)
      assert_equal expected, actual, "#{key}: <#{expected.inspect}> expected but was <#{actual.inspect}>"
    end
  end


  #####################
  ### Class Methods ###
  #####################

  def test_fetch_by_name
    project = Project.fetch_by_name(@existing_project.name)
    assert project
    assert_equal @existing_project.id, project.id
    check_project_fields(project, @existing_project_data)
  end

  def test_fetch_nonexistent_by_name
    assert_nil Project.fetch_by_name('non-existent')
  end


  ########################
  ### Instance Methods ###
  ########################

  def test_create
    assert @existing_project
    assert @existing_project.id
    check_project_fields(@existing_project, @existing_project_data)

    # ensure created time is set
    # (timestamps may have been a second or two ago at this point, give some allowance for that)
    created_delta = Time.now.to_i - @existing_project.created_timestamp
    assert created_delta < 3

    # adds iteslf to project id list on associated account
    assert @existing_project.account.project_ids.include?(@existing_project.id)
  end

  def test_save_with_missing_fields
    Project.fields.each do |name, options|
      if options[:required]
        orig_value = @existing_project.send(name)
        @existing_project.send("#{name}=", nil)
        assert_raises Project::InvalidDataError, "#{name} should be required" do
          @existing_project.save
        end
        empty_value =
          case options[:type]
          when :string
            ' '
          when :integer
            0
          else
            ' '
          end
        @existing_project.send("#{name}=", empty_value)
        assert_raises Project::InvalidDataError, "#{name} should be required" do
          @existing_project.save
        end
        @existing_project.send("#{name}=", orig_value)
      end
    end
  end

  def test_delete!
    @existing_project.delete!
    assert Project.fetch(@existing_project.id).nil?, 'Project was fetched by id after deletion'
    assert !Project.exists?(@existing_project.id), 'Project exists after deletion'

    # removes iteslf from project id list on associated account
    assert !@existing_project.account.project_ids.include?(@existing_project.id)
  end

  def test_count_photos
    10.times do |i|
      assert_equal i, @existing_project.count_photos
      @existing_project.add_photo(@test_photo_path)
      assert_equal i + 1, @existing_project.count_photos
    end
  end

  def test_add_photo
    data = @existing_project.add_photo(@test_photo_path)
    assert_equal 1, @existing_project.count_photos
    path = @existing_project.send(:photo_path, data['id'])
    assert File.exists?(path)
    assert_equal JPEGHeader, File.read(path, JPEGHeader.length)
  end

  def test_remove_photo
    data = @existing_project.add_photo(@test_photo_path)
    path = @existing_project.send(:photo_path, data['id'])
    @existing_project.remove_photo(data['id'])
    assert !File.exists?(path)
    assert_equal 0, @existing_project.count_photos
  end

  def test_photo_data
    data = @existing_project.add_photo(@test_photo_path)
    assert_equal data, @existing_project.photo_data(data['id'])
  end

  def test_photo_urls
    data = @existing_project.add_photo(@test_photo_path)
    urls = @existing_project.photo_urls
    assert_equal 1, urls.length

    url = urls.first
    assert_equal "/photos/#{@existing_project.id}/#{data['id']}.jpg", url
    assert_equal data['url'], url
  end

  def test_photo_paths
    @existing_project.add_photo(@test_photo_path)
    assert_equal 1, @existing_project.photo_paths.length
  end

  def test_photos
    assert_equal [], @existing_project.photos
    data = nil
    5.times do |i|
      data = @existing_project.add_photo(@test_photo_path)
    end
    assert_equal [data] * 5, @existing_project.photos
  end

  def test_account
    assert @existing_project.account
    assert_equal @existing_account.id, @existing_project.account.id
  end

end
