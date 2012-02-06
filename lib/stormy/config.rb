# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'redis'

module Stormy

  class Config

    DefaultConfig = {
    }

    ConfigTypes = {
    }

    # shared instance
    def self.instance
      @@instance ||= new
    end

    def initialize
      reload!
      if config.size == 0 && DefaultConfig.size > 0
        redis.hmset(config_key, *DefaultConfig.to_a.flatten)
        reload!
      end
    end

    def config_key
      @config_key ||= Stormy.key('config')
    end

    def config
      @config ||= redis.hgetall(config_key)
    end

    def redis
      @redis ||= Redis.new
    end

    def reload!
      @config = nil
      config
      if config.size > 0
        ConfigTypes.each do |name, type|
          if type == :integer
            config[name] = config[name].to_i
          elsif type == :boolean
            config[name] = config[name] == 'true'
          end
        end
      end
    end

    def method_missing(name, *args)
      name = name.to_s
      # TODO: decide if we should call super for unknown names
      if name.ends_with?('=')
        name = name.sub(/=$/, '')
        value = args.first
        redis.hset(config_key, name, value)
        config[name] = value
      elsif config.has_key?(name)
        config[name]
      elsif DefaultConfig.has_key?(name)
        value = DefaultConfig[name]
        redis.hset(config_key, name, value)
        config[name] = value
      else
        super(name.to_sym, *args)
      end
    end

  end

end
