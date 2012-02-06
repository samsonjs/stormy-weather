# Copyright 2011 Beta Street Media

module Stormy
  class Server < Sinatra::Base

    get '/projects' do
      authorize!
      @projects = current_account.sorted_projects
      title 'Projects'
      stylesheet 'projects'
      script 'projects'
      erb :projects
    end

    get '/project/:id' do |id|
      authorize_project!(id)
      if current_project.name.blank?
        title "Project ID #{id}"
      else
        title current_project.name
      end
      stylesheet 'jquery.lightbox-0.5'
      script 'jquery.lightbox-0.5'
      script 'jquery.dragsort'
      stylesheet 'edit-project'
      script 'edit-project'

      # fuck IE
      if request.user_agent.match(/msie/i)
        stylesheet 'uploadify'
        script 'swfobject'
        script 'jquery.uploadify.v2.1.4'
      end

      @errors = session.delete('errors')
      @project = current_project
      erb :'edit-project'
    end

    post '/project/update' do
      id = params['id']
      if admin_authorized?
        current_project(id)
      else
        authorize_project!(id)
      end

      begin
        current_project.update(params)

        flash[:notice] = "Project saved."
      rescue Project::InvalidDataError => e
        flash[:warning] = "There are some errors with your project."
        session['errors'] = e.fields
      end

      redirect '/project/' + params['id']
    end

    post '/project/add-photo' do
      content_type :json
      id = params['id']
      if admin_authorized?
        current_project(id)
      else
        authorize_project_api!(id)
      end

      if photo = current_project.add_photo(params['photo'][:tempfile].path)
        ok({
          'n' => current_project.count_photos,
          'photo' => photo
        })
      else
        fail('limit')
      end
    end

    # fuck IE
    post '/uploadify' do
      content_type :json
      authorize_project_api!(params['id'])
      if photo = current_project.add_photo(params['Filedata'][:tempfile].path)
        ok({
          'n' => current_project.count_photos,
          'photo' => photo
        })
      else
        content_type 'text/plain'
        bad_request
      end
    end

    post '/project/remove-photo' do
      content_type :json
      if admin_authorized?
        current_project(params['id'])
      else
        authorize_project_api!(params['id'])
      end

      current_project.remove_photo(params['photo_id'])
      ok({
        'photos' => current_project.photos
      })
    end

    post '/project/photo-order' do
      content_type :json
      id = params['id']
      if admin_authorized?
        current_project(id)
      else
        authorize_project_api!(id)
      end

      current_project.photo_ids = params['order']
      current_project.save!
      ok
    end

  end
end
