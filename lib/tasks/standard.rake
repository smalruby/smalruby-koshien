require "standard/rake"

desc "Run Standard Ruby linter"
task :standard do
  sh "bundle exec standardrb"
end

desc "Auto-fix Standard Ruby issues"
task "standard:fix" do
  sh "bundle exec standardrb --fix"
end
