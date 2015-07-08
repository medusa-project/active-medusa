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
  starting_branch = nil
  orphan_exists = false
  `git branch`.each_line do |line|
    branch = line[0].gsub('*', '').strip
    if line[0] == '*'
      starting_branch = branch
    elsif branch == 'gh-pages'
      orphan_exists = true
    end
  end

  # generate docs
  `yard`

  # copy them to a temp dir
  tmp_dir = Dir.tmpdir
  FileUtils.cp_r('doc/yard', tmp_dir)

  # switch to gh-pages branch
  if orphan_exists
    `git checkout gh-pages`
  else
    `git checkout --orphan gh-pages`
  end

  # wipe it clean and copy the docs back into it
  `git rm -rf .`
  `cp -r #{File.join(tmp_dir, 'yard', '*')} .`

  # commit and push
  `git add *`
  `git commit -m 'Update website'`
  `git push origin gh-pages`

  # cleanup
  FileUtils.rm_rf(File.join(tmp_dir, 'yard'))
  `git checkout #{starting_branch}`
end
