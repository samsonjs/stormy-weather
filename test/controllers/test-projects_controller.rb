#!/usr/bin/env ruby
#
# Copyright 2011 Beta Street Media

require 'common'

class ProjectsControllerTest < Stormy::Test::ControllerCase

  include Stormy::Test::Helpers::Accounts
  include Stormy::Test::Helpers::Admins
  include Stormy::Test::Helpers::Projects
  include Stormy::Helpers::Authorization

  def setup
    header 'User-Agent', "rack/test (#{Rack::Test::VERSION})"
    setup_accounts
    setup_projects
    sign_in

    @updated_project_data ||= {
      :id   => @existing_project.id,
      :name => 'the super amazing project'
    }
  end

  def teardown
    teardown_projects
    teardown_accounts
  end

  def create_other_account_and_project
    @other_account = Account.create(@account_data)
    @new_project_data['account_id'] = @other_account.id
    @other_project = Project.create(@new_project_data)
  end

  def photo_filenames
    @photo_filenames ||= Dir[photo_file('*.jpg')]
  end

  def add_photo(filename = photo_filenames.first)
    post '/project/add-photo', {
      :id    => @existing_project.id,
      :photo => Rack::Test::UploadedFile.new(filename, 'image/jpeg')
    }
    @existing_project.reload!
    photo_id = @existing_project.photo_ids.last
    assert_response_json_ok(
      'n' => @existing_project.count_photos,
      'photo' => {
        'id'  => photo_id,
        'url' => @existing_project.photo_url(photo_id)
      }
    )
  end

  def add_all_photos
    photo_filenames.each { |f| add_photo(f) }
  end


  ##################
  ### Projects ###
  ##################

  def test_projects
    # must be authorized
    sign_out
    get '/projects'
    assert_redirected '/sign-in'

    # now we can get the projects page
    sign_in
    get '/projects'
    assert_ok
  end

  def test_project
    get "/project/#{@existing_project.id}"
    assert_ok
  end

  def test_project_without_a_name
    @existing_project.name = ''
    @existing_project.save!
    get "/project/#{@existing_project.id}"
    assert_ok
  end

  def test_cannot_access_others_projects
    create_other_account_and_project
    get "/project/#{@other_project.id}"
    assert_redirected '/projects'
    follow_redirect!
    assert_ok
    assert last_response.body.match(/no such project/i)
  end

  def test_update_project
    data = @updated_project_data
    post '/project/update', data
    assert_redirected "/project/#{data[:id]}"
    @existing_project.reload!
    data.each do |name, value|
      assert_equal value, @existing_project.send(name)
    end
  end

  def test_update_project_with_invalid_fields
    expected_name = @existing_project.name
    data = {
      :id   => @existing_project.id,
      :name => ''
    }
    post '/project/update', data
    assert_redirected "/project/#{data[:id]}"
    @existing_project.reload!
    assert_equal expected_name, @existing_project.name
  end

  def test_update_project_by_admin
    setup_admins
    post '/admin/sign-in', @admin_data

    data = @updated_project_data
    post '/project/update', data
    assert_redirected "/project/#{data[:id]}"

    teardown_admins
  end

  def test_cannot_update_others_projects
    create_other_account_and_project
    post '/project/update', { :id => @other_project.id }
    assert_redirected '/projects'
    follow_redirect!
    assert_ok
    assert last_response.body.match(/no such project/i)
  end

  def test_add_photo
    # also test /uploadify which is used for photo uploads in IE
    %w[/project/add-photo /uploadify].each_with_index do |path, i|
      post path, {
        :id       => @existing_project.id,
        # /project/add-photo
        :photo    => Rack::Test::UploadedFile.new(photo_filenames.first, 'image/jpeg'),
        # /uploadify
        :Filedata => Rack::Test::UploadedFile.new(photo_filenames.first, 'image/jpeg')
      }
      @existing_project.reload!
      photo_id = @existing_project.photo_ids[i]
      assert_response_json_ok({
        'n' => i + 1,
        'photo' => {
          'id'  => photo_id,
          'url' => @existing_project.photo_url(photo_id)
        }
      })
    end
  end

  def test_add_photo_fails_at_photo_limit
    Project::MaxPhotos.times { add_photo }

    post '/project/add-photo', {
      :id    => @existing_project.id,
      :photo => Rack::Test::UploadedFile.new(photo_filenames.first, 'image/jpeg'),
    }
    assert_response_json_fail('limit')

    post '/uploadify', {
      :id       => @existing_project.id,
      :Filedata => Rack::Test::UploadedFile.new(photo_filenames.first, 'image/jpeg'),
    }
    assert_bad_request
  end

  def test_add_photo_by_admin
    setup_admins
    post '/admin/sign-in', @admin_data

    post '/project/add-photo', {
      :id    => @existing_project.id,
      :photo => Rack::Test::UploadedFile.new(photo_filenames.first, 'image/jpeg'),
    }
    @existing_project.reload!
    photo_id = @existing_project.photo_ids.last
    assert_response_json_ok({
      'n' => 1,
      'photo' => {
        'id'  => photo_id,
        'url' => @existing_project.photo_url(photo_id)
      }
    })

    teardown_admins
  end

  def test_remove_photo
    add_photo
    photo_id = @existing_project.photo_ids.last
    post '/project/remove-photo', {
      :id       => @existing_project.id,
      :photo_id => photo_id
    }
    @existing_project.reload!
    assert_response_json_ok('photos' => [])
    assert_equal 0, @existing_project.count_photos
  end

  def test_remove_photo_by_admin
    setup_admins
    post '/admin/sign-in', @admin_data

    add_photo
    photo_id = @existing_project.photo_ids.last
    post '/project/remove-photo', {
      :id       => @existing_project.id,
      :photo_id => photo_id
    }
    @existing_project.reload!
    assert_response_json_ok('photos' => [])
    assert_equal 0, @existing_project.count_photos

    teardown_admins
  end

  def test_reorder_photos
    add_all_photos
    @existing_project.reload!
    photo_ids = @existing_project.photo_ids
    # move the first to the end
    photo_ids.push(photo_ids.shift)
    post '/project/photo-order', {
      :id => @existing_project.id,
      :order => photo_ids
    }
    @existing_project.reload!
    assert_equal photo_ids, @existing_project.photo_ids
  end

  def test_reorder_photos_by_admin
    setup_admins
    post '/admin/sign-in', @admin_data

    add_all_photos
    @existing_project.reload!
    photo_ids = @existing_project.photo_ids
    # move the first to the end
    photo_ids.push(photo_ids.shift)
    post '/project/photo-order', {
      :id => @existing_project.id,
      :order => photo_ids
    }
    @existing_project.reload!
    assert_equal photo_ids, @existing_project.photo_ids

    teardown_admins
  end

end
