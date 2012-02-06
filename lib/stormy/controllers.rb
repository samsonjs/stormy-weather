# Copyright 2012 Sami Samhuri <sami@samhuri.net>

Dir[File.dirname(__FILE__) + '/controllers/*.rb'].each do |f|
  require 'stormy/controllers/' + File.basename(f)
end
