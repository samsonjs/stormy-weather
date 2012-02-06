# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'stormy/models/base'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each do |f|
  require 'stormy/models/' + File.basename(f)
end
