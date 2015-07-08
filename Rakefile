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
  # make sure there are no outstanding changes before beginning
  raise 'Outstanding changes' unless
      `git status`.include?('nothing to commit, working directory clean')
  begin
    # get the current git branch
    starting_branch = nil
    orphan_exists = false
    `git branch --no-color`.each_line do |line|
      branch = line.gsub('*', '').strip
      starting_branch = branch if line[0] == '*'
      orphan_exists = true if branch == 'gh-pages'
    end

    # generate docs
    `yard`

    # copy them to a temp dir
    tmp_dir = Dir.tmpdir
    FileUtils.cp_r('doc/yard', tmp_dir)

    # switch to gh-pages branch
    if orphan_exists
      result = system('git checkout gh-pages')
    else
      result = system('git checkout --orphan gh-pages')
    end
    raise 'Failed to checkout gh-pages' unless result

    # wipe it clean and copy the docs back into it
    `git rm -rf .`
    `cp -r #{File.join(tmp_dir, 'yard', '*')} .`

    # commit and push
    `git add *`
    `git commit -m 'Update website'`
    `git push origin gh-pages`
  ensure
    # cleanup
    FileUtils.rm_rf(File.join(tmp_dir, 'yard'))
    `git checkout #{starting_branch}`
  end
end
