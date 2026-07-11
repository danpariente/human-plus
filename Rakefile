# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.test_files = FileList["test/test_*.rb"]
  t.warning = false
end

task default: :test

desc "Build the ri database from the source — the docs are the book"
task(:ri) { sh "rdoc --format=ri --output=.ri lib" }

desc "Read the book: rake 'teach[HumanPlus::Human#surrender]'"
task(:teach, [:name]) { |_, a| sh "ri -d .ri #{a[:name]}" }
