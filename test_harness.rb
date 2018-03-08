require File.join('.', 'boot')

Resque.enqueue_in(10, RetriedResqueMessage, 'hello!')
