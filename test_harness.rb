require File.join('.', 'boot')

Resque.enqueue_in(1, RetriedResqueMessage, {foo: 'bar', baz: 1000, bing: [1,2,3]})
