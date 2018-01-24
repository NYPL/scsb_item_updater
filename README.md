# SCSB Item Updater

This app consumes messages produced by [NYPL/nypl-recap-admin](https://github.com/NYPL/nypl-recap-admin).  
It pushes updated item information (from our platform) into SCSB's system via
SCSB's API.

The rough workflow for this is, per barcode:

1.  Get barcode customer code (per barcode) from SCSB's [search endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/search-records-rest-controller/search).
2.  Hit [our platform api](https://platformdocs.nypl.org/#/recap/get_v0_1_recap_nypl_bibs) with the customer code and barcode and receive back SCSBXML.
3.  Do minor massaging and post updated information to the [SCSB "submit collection" endpoint](https://uat-recap.htcinc.com:9093/swagger-ui.html#!/shared-collection-rest-controller/submitCollection).

After the updates - this app will, in some way, shape or form send an email to
the staff who initiated the update. (Success / failure)

## Dependencies & Requirements

## Installing & Running locally

1.  `cp ./config/.env.example ./config/.env`
1.  `gem install bundler --version 1.16.1`
1.  `bundle install`

## Usage

## Deploying

TODO: Mention Delay
TODO: Add this to our existing SCSB architecture diagram
