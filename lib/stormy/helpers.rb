# Copyright 2012 Sami Samhuri <sami@samhuri.net>

Dir[File.dirname(__FILE__) + '/helpers/*.rb'].each do |f|
  require 'stormy/helpers/' + File.basename(f)
end
