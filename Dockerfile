FROM ruby:3.2.2

RUN apt update; apt install -y r10k librarian-puppet

WORKDIR /app
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
RUN bundle install

ADD . /app

EXPOSE 4567

CMD ["ruby", "web.rb"]
