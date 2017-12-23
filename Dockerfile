FROM ruby:2.3.1-slim
COPY Gemfile* /tmp/
WORKDIR /tmp

RUN gem install bundler && \
    apt-get update && \
    apt-get install -y build-essential libsqlite3-dev rsync nodejs && \
    bundle install --path vendor/bundle

RUN mkdir -p /app/vendor/bundle
WORKDIR /app
RUN cp -R /tmp/vendor/bundle vendor
COPY application.tar.gz /tmp
CMD cd /tmp && \
    tar -xzf application.tar.gz && \
    rsync -a blog/ /app/ && \
    cd /app && \
    RAILS_ENV=production bundle exec rake db:migrate && \
    RAILS_ENV=production bundle exec rake assets:precompile && \
    RAILS_ENV=production bundle exec rails s -b 0.0.0.0 -p 3000
