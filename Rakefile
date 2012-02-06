# Copyright 2012 Sami Samhuri <sami@samhuri.net>

require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/**/test-*.rb']
end

task 'nuke-test-data' do
  require 'rubygems'
  require 'bundler/setup'
  require 'redis'

  redis = Redis.new
  redis.keys('TEST:stormy:*').each do |key|
    redis.del key
  end
end

MinifiedCSSDir = 'public/css-min'
MinifiedJSDir = 'public/js-min'

desc "Minifies JS and CSS"
task :minify do
  puts "Minifying JavaScript..."
  Dir.mkdir(MinifiedJSDir) unless File.exists?(MinifiedJSDir)
  Dir['public/js/*.js'].each do |path|
    filename = File.basename(path)
    out = File.join(MinifiedJSDir, filename)
    if !File.exists?(out) || File.mtime(path) > File.mtime(out)
      puts " * #{filename}"
      `bin/closure <"#{path}" >"#{out}"`
    end
  end

  puts "Minifying CSS..."
  Dir.mkdir(MinifiedCSSDir) unless File.exists?(MinifiedCSSDir)
  Dir['public/css/*.css'].each do |path|
    filename = File.basename(path)
    out = File.join(MinifiedCSSDir, filename)
    if !File.exists?(out) || File.mtime(path) > File.mtime(out)
      puts " * #{filename}"
      `bin/yui-compressor "#{path}" "#{out}"`
    end
  end

  puts "Done."
end
