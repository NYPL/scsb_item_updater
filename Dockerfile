FROM ruby:2.5.0
WORKDIR /app
ADD . /app
RUN bundle install --without development
ENTRYPOINT ["ruby", "/app/consume_messages.rb"]
