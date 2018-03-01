# SCSB Item Updater

| Branch        | Status                                                                                                                                                   |
|:--------------|:---------------------------------------------------------------------------------------------------------------------------------------------------------|
| `master`      | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=master)](https://travis-ci.org/NYPL-discovery/scsb_item_updater)      |
| `development` | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=development)](https://travis-ci.org/NYPL-discovery/scsb_item_updater) |
| `production`  | [![Build Status](https://travis-ci.org/NYPL-discovery/scsb_item_updater.svg?branch=production)](https://travis-ci.org/NYPL-discovery/scsb_item_updater)  |

This app consumes messages produced by [NYPL/nypl-recap-admin](https://github.com/NYPL/nypl-recap-admin).  
It pushes updated item information (from our platform) into SCSB's system via
SCSB's API.

The rough workflow for this is, per barcode:

1.  Get barcode customer code (per barcode) from SCSB's [search endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/search-records-rest-controller/search).
2.  Hit [our platform api](https://platformdocs.nypl.org/#/recap/get_v0_1_recap_nypl_bibs) with the customer code and barcode and receive back SCSBXML.
3.  Do minor massaging and post updated information to the [SCSB "submit collection" endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/shared-collection-rest-controller/submitCollection).

After the updates - this app will, in some way, shape or form send an email to
the staff who initiated the update. (Success / failure)

## Installing & Running

### Locally

#### Setup

1.  Ensure you have Redis installed & running on your machine (`brew install redis`)
1.  `cp ./config/.env.example ./config/.env`
1.  `gem install bundler --version 1.16.1`
1.  `bundle install`

#### Usage

`ruby ./dequeue_from_sqs.rb`

### Docker

#### Building a Docker Image

`docker build --no-cache .`

#### Running from Docker build

```
docker run --env-file ./config/.env [IMAGENAME-OR-SHA]
```

_...for a complete list of environment variables see `./config/.env`_

1.  `ruby dequeue_from_sqs.rb.rb`
2.  Make sure the environment variable of `IS_DRY_RUN` is set correctly. If set to false, it will update the incomplete barcodes with SCSBXML in the assigned ReCap environment. If set to true, it will run the script without updating the barcodes.

## Git Workflow & Deployment

Our branches (in order or stability are):

| Branch      | Environment | AWS Account     |
|:------------|:------------|:----------------|
| master      | none        | none            |
| development | development | aws-sandbox     |
| production  | production  | aws-digital-dev |

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
