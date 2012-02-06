# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'digest/sha1'
require 'fileutils'
require 'RMagick'

module Stormy
  module Models
    class Project < Base

      # max width or height in pixels
      MaxPhotoSize = 1200
      MaxPhotos = 10

      name 'project'

      field :id, :required => true

      field :name, :required => true, :updatable => true

      field :account_id
      field :created_timestamp, :type => :integer, :required => true
      field :fizzled_timestamp, :type => :integer
      field :funded_timestamp, :type => :integer
      field :photo_ids, :type => :json, :default => []

      @@project_name_index_key = Stormy.key('index:project-name')

      def self.fetch_by_name(name)
        if id = id_from_name(name)
          fetch(id)
        end
      end

      def self.id_from_name(name)
        redis.hget(@@project_name_index_key, name.strip.downcase)
      end

      def create
        self.id = UUID.generate unless id.present?
        self.created_timestamp = Time.now.to_i

        super

        # add to index
        redis.hset(@@project_name_index_key, name.downcase, id)

        account.add_project_id(id) if account

        self
      end

      def delete!
        if super
          remove_all_photos!
          account.remove_project_id(id) if account
          redis.hdel(@@project_name_index_key, name.strip.downcase)
        end
      end

      def funded?
        funded_timestamp > 0
      end

      def funded!
        self.funded_timestamp = Time.now.to_i
        save!
      end

      def fizzled?
        fizzled_timestamp > 0
      end

      def fizzled!
        self.fizzled_timestamp = Time.now.to_i
        save!
      end

      def count_photos
        photo_ids.length
      end

      def add_photo(path)
        unless count_photos >= MaxPhotos
          photo = Magick::Image.read(path).first
          photo.auto_orient!
          photo.change_geometry("#{MaxPhotoSize}x#{MaxPhotoSize}>") { |cols, rows, img| img.resize!(cols, rows) }
          photo.format = 'jpg'

          FileUtils.mkdir_p(photo_dir) unless File.exists?(photo_dir)

          photo_id = Digest::SHA1.hexdigest(photo.to_blob)
          photo.write(photo_path(photo_id)) { self.quality = 80 }

          photo_ids << photo_id
          save!

          photo_data(photo_id)
        end
      end

      def remove_photo(photo_id)
        path = photo_path(photo_id)
        if i = photo_ids.index(photo_id)
          photo_ids.delete_at(i)
        end
        FileUtils.rm(path) if File.exists?(path) && !photo_ids.include?(photo_id)
        save!
      end

      def photo_paths
        photo_ids.map { |id| photo_path(id) }
      end

      def photo_urls
        photo_ids.map { |photo_id| "/photos/#{id}/#{photo_id}.jpg" }
      end

      def photo_url(photo_id)
        "/photos/#{id}/#{photo_id}.jpg"
      end

      def photo_data(photo_id)
        {
          'id' => photo_id,
          'url' => photo_url(photo_id)
        }
      end

      def photos
        photo_ids.map { |id| photo_data(id) }
      end

      def account
        if account_id
          @account ||= Account.fetch(account_id)
        end
      end


      private

      def photo_dir
        File.join(Stormy::PhotoDir, @id)
      end

      def photo_path(id)
        File.join(photo_dir, "#{id}.jpg")
      end

      def photos_key
        "#{key}:photos"
      end

      def remove_all_photos!
        FileUtils.rm_rf(photo_dir) if File.exists?(photo_dir)
        self.photo_ids = []
      end

    end
  end
end
