require File.join('.', 'boot')
Application.logger.info("Resque worker online")
require 'resque/tasks'
require 'resque/scheduler/tasks'

namespace :resque do
  #  Relies on `QUEUE` and the env vars used by resque-scheduler: https://github.com/resque/resque-scheduler#environment-variables
  desc "Executes resque:scheduler & resque:scheduler."
  task :work_and_schedule do
    Thread.new { Rake::Task['resque:work'].invoke }
    Rake::Task['resque:scheduler'].invoke
  end
end
