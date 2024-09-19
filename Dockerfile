FROM ruby:3.3.3
WORKDIR /app
ADD . /app
RUN bundle install --without development test
ENTRYPOINT ["ruby", "/app/dequeue_from_sqs.rb"]
