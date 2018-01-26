FROM ruby:2.5.0
WORKDIR /app
ADD . /app
RUN bundle install --without development test
ENTRYPOINT ["ruby", "/app/consume_messages.rb"]
