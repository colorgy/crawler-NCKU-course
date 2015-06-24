web: bundle exec thin start -p $PORT
worker: bundle exec sidekiq -c 10 -t 0 -v -r ./app.rb
