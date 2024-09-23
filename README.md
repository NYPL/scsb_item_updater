# SCSB Item Updater

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

Messages read off Redis look like this:

```
{ "user_email": "email@xample.com", "barcodes": ["33433132060058"], "action": "update" }
```

If the message contains a "source" of "bib-item-store-update", the job will be processed immediately rather than waiting 1hr:

```
{ "user_email": "email@xample.com", "barcodes": ["33433132060058"], "action": "update", "source": "bib-item-store-update" }
```

If you need to debug a processing issue without using SCSBuster or incurring the 1hr delay, you can write messages resembling the above to the [qa](https://console.aws.amazon.com/sqs/v2/home?region=us-east-1#/queues/https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F946183545209%2Fsierra-updates-for-scsb-qa/send-receive) or [production](https://console.aws.amazon.com/sqs/v2/home?region=us-east-1#/queues/https%3A%2F%2Fsqs.us-east-1.amazonaws.com%2F946183545209%2Fsierra-updates-for-scsb-production/send-receive) queues directly.

#### Working Redis

1.  `ProcessResqueMessage`, a [resque job](https://github.com/resque/resque#overview), uses an instance of `ResqueMessageHandler` do all the hard work.
1.  `ResqueMessageHandler` is what actually inspects the message, makes the appropriate API calls (through other classes), and conditionally sends error reports.

## Installing & Running

### Locally

#### Setup

1.  Ensure you have Redis installed & running on your machine (`brew install redis`)
1.  `cp ./config/.env.example ./config/.env` (and fill in the values)
1.  `gem install bundler --version 2.5.11`
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

## Running Unit Tests
You can run the unit tests natively if you have the necessary dependencies installed. The docker containers are not really set up to do this, but one can still be used by following these steps:
```
> docker-compose up -d
> docker-compose exec work_sqs_messages bash
> bundle install --with development test
> RAILS_ENV=test bundle exec rspec
```

## Git Workflow & Deployment

Our branches (in order or stability are):

| Branch      | Environment | AWS Account      |
|:------------|:------------|:-----------------|
| qa          | qa          | nypl-digital-dev |
| production  | production  | nypl-digital-dev |

We use the workflow [PRs Target Main, Merge to Deployment Branches](https://github.com/NYPL/engineering-general/blob/master/standards/git-workflow.md#prs-target-main-merge-to-deployment-branches)

### Cutting A Feature Branch

1. Feature branches are cut from `qa`.
2. Once the feature branch is ready to be merged, open a pull request of the branch _into_ qa.

### Deploying

We use GitHub Actions for continuous deployment.
Merging to certain branches automatically deploys to the environment associated to
that branch.

Merging `feature` => `qa` automatically deploys to the qa environment.
Merging `qa` => `production` automatically deploys to the production environment.

Please backmerge production into qa after a release.

### Environmental Variable Config in Deployed Components

All config may be managed via AWS console
 * [QA cluster](https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/scsb-item-updater-qa/services)
 * [Production cluster](https://console.aws.amazon.com/ecs/home?region=us-east-1#/clusters/scsb-item-updater-production/services)

To edit environmental variables:
1. Create a Task Definition Revision
  - Navigate to "Tasks" tab
  - Follow "scsb-item-updater..." link under "Task definition" column
  - Click "Create new revision"
  - Under "Container Definitions" follow either the "scsb_item_updater_sqs_consumer" or "scsb_item_updater_redis_consumer" link depending on if you need to update config for the component that reads jobs off the external SQS or the component that processes jobs from the internal Redis (although they appear to have a lot of the same config)
  - Make your changes in the resulting "Edit Container" modal and finish by clicking "Update"
  - Create your revision via "Create" button
2. Activate the new task definition version
  - Navigate to "Services" tab
  - Enable the checkbox next to the sole service
  - Click "Update"
  - Select your new version under "Task Definition > Revision"
  - Follow "Next Step" through several pages to save.
