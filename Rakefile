require 'bundler/gem_tasks'
require 'rake/testtask'
require 'fileutils'

Rake::TestTask.new do |t|
  t.libs << File.expand_path('lib')
  t.libs << File.expand_path('test')
  t.pattern = 'test/*_test.rb'
end

desc 'Run tests'
task :default => :test

desc 'Publish documentation'
task :publish_docs do
  # get the current git branch
  branch = nil
  `git branch`.each_line do |line|
    if line[0] == '*'
      branch = line[0].split('*').last.strip
      break
    end
  end
  # generate docs
  `yard`
  # copy them to a temp dir
  tmp_dir = Dir.tmpdir
  FileUtils.cp_r('doc/yard', tmp_dir)
  # switch to gh-pages branch
  `git checkout --orphan gh-pages`
  # wipe it clean and copy the docs back into it
  `git rm -rf .`
  FileUtils.cp_r(File.join(tmp_dir, 'yard', '*'), '.')
  # commit and push
  `git add *`
  `git commit -m 'Update website'`
  `git push origin gh-pages`
  # cleanup
  FileUtils.rm_rf(File.join(tmp_dir, 'yard'))
  `git checkout #{branch}`
end
