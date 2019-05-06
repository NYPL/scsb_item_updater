# SCSB Item Updater

| Branch        | Status                                                                                                                                                   |
|:--------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `master`      | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=master)](https://travis-ci.org/NYPL-discovery/scsb_item_updater)      |
| `development` | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=development)](https://travis-ci.org/NYPL-discovery/scsb_item_updater) |
| `qa`          | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=qa)](https://travis-ci.org/NYPL-discovery/scsb_item_updater)          |
| `production`  | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=production)](https://travis-ci.org/NYPL-discovery/scsb_item_updater)  |

This app consumes messages produced by [NYPL/nypl-recap-admin](https://github.com/NYPL/nypl-recap-admin).  
It pushes updated item information (from our platform) into SCSB's system via
SCSB's API.

The rough workflow for this is, per barcode:

1.  Get barcode customer code (per barcode) from SCSB's [search endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/search-records-rest-controller/search).
2.  Hit [our platform api](https://platformdocs.nypl.org/#/recap/get_v0_1_recap_nypl_bibs) with the customer code and barcode and receive back SCSBXML.
3.  Do minor massaging and post updated information to the [SCSB "submit collection" endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/shared-collection-rest-controller/submitCollection).

## Application Architecture

### High Level Workflow:

This application...

1.  Consumes messages from Amazon SQS.
2.  Persists those messages into Redis, and delete them from SQS.
3.  Works messages from Redis using [resque](https://github.com/resque/resque) in a separate process.

### Details

#### From SQS -> Redis

1.  `dequeue_from_sqs.rb` consumes messages from SQS. It does that by instantiating an `SQSMessageHandler`.
1.  `SQSMessageHandler` makes sure that a message is well formed & old enough to be worked.  
If it is, it's persisted into Redis and deleted from SQS.

#### Working Redis

1.  `ProcessResqueMessage`, a [resque job](https://github.com/resque/resque#overview), uses an instance of `ResqueMessageHandler` do all the hard work.
1.  `ResqueMessageHandler` is what actually inspects the message, makes the appropriate API calls (through other classes), and conditionally sends error reports.

## Installing & Running

### Locally

#### Setup

1.  Ensure you have Redis installed & running on your machine (`brew install redis`)
1.  `cp ./config/.env.example ./config/.env`
1.  `gem install bundler --version 1.16.1`
1.  `bundle install`

#### Running Natively Locally

1. `ruby ./dequeue_from_sqs.rb` and in another tab...`QUEUE=* rake resque:work`
1.  Make sure the environment variable of `IS_DRY_RUN` is set correctly. If set to false, it will update the incomplete barcodes with SCSBXML in the assigned ReCap environment. If set to true, it will run the script without updating the barcodes.

Ad hoc testing of resque workers in isolation can be achieved by:

 - Open one terminal with `QUEUE=* rake resque:work`
 - Open another terminal tab with `irb -r './boot'` and add arbitrary resque messages like:
   - `Resque.enqueue(ProcessResqueMessage, { "user_email" => "user@example.com", "barcodes" => [ "1234" ], "action" => "update", "queued_at" => Time.now.to_f * 100 }.to_json)`

#### Running From Docker Locally

You can use docker and [`docker-compose`](https://docs.docker.com/compose/overview/) to run the app locally too.
`docker compose` will even bring up its own instance of Redis.

1.  Ensure you have correct environment variables setup in `./config/.env`
1.  Build the docker image: `docker build --no-cache -t scsb_item_updater:latest .`
1.  `docker compose up`

## Running Resque

#### Debugging Resque Workers

From an IRB session (`$bundle exec irb -r ./boot.rb`).

This [Stack Overflow thread](http://stackoverflow.com/questions/8798357/inspect-and-retry-resque-jobs-via-redis-cli) has good tips on ways to inspect the queue.

```ruby
> Resque.info
  => {:pending=>0, :processed=>193, :queues=>1, :workers=>2, :working=>0, :failed=>168, :servers=>["redis://fqdn.com:6379/0"], :environment=>"development"}

# Print exceptions
> Resque::Failure.all(0,20).each { |job|
     puts "#{job["exception"]}  #{job["backtrace"]}"
  }

# Reset the failed jobs count
> Resque::Failure.clear

# Restarting all failed jobs
(Resque::Failure.count-1).downto(0).each do |i|
  Resque::Failure.requeue(i)
end
```

## Git Workflow & Deployment

Our branches (in order or stability are):

| Branch      | Environment | AWS Account      |
|:------------|:------------|:-----------------|
| master      | none        | none             |
| development | development | nypl-sandbox     |
| qa          | qa          | nypl-digital-dev |
| production  | production  | nypl-digital-dev |

### Cutting A Feature Branch

1. Feature branches are cut from `master`.
2. Once the feature branch is ready to be merged, file a pull request of the branch _into_ master.

### Deploying

We use Travis for continuous deployment.
Merging to certain branches automatically deploys to the environment associated to
that branch.

Merging `master` => `development` automatically deploys to the development environment. (after tests pass).  
Merging `development` => `production` automatically deploys to the production environment. (after tests pass).

For insight into how CD works look at [.travis.yml](./.travis.yml) and the
[continuous_deployment](./continuous_deployment) directory.
The approach is inspired by [this blog post](https://dev.mikamai.com/2016/05/17/continuous-delivery-with-travis-and-ecs/) ([google cached version](https://webcache.googleusercontent.com/search?q=cache:NodZ-GZnk6YJ:https://dev.mikamai.com/2016/05/17/continuous-delivery-with-travis-and-ecs/+&cd=1&hl=en&ct=clnk&gl=us&client=firefox-b-1-ab)).
