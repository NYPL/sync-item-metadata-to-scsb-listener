# Sync Item Metadata to SCSB Listener

This is a small Ruby app deployed as Kinesis Stream listener, sniffing for Bib/Item updates that should trigger syncing metadata to SCSB.

The app listens on all Bib/Item streams (including BibBulk and ItemBulk). When it receives a record, the process is as follows:

**On receiving Bib updates**:
 1. Check bib id against list of known mixed bibs. If match found, we *assume* it has items in SCSB.
 2. Query items service for first items associated with bibid. If item is a research item (by checking Item Type & location), we assume there may be items in SCSB

If either check above concludes that there *may* be items in SCSB, we hit the `/searchService/search` endpoint with `fieldValue: ".b[BIBID][SIERRAMOD11CHECKDIGIT]"` and `fieldName: "OwningInstitutionBibId"` to identify all item barcodes we'll need to queue sync jobs for. Create a metadata sync job using the Platform API's recap/sync-item-metadata-to-scsb endpoint.

**On receiving Item updates**:
 1. Check item's location for presense of the Recap "rc" prefix. If found, item assume to exist an SCSB. Hit the scsb `/searchService/search` endpoint with `fieldValue: ".i[ITEMID][SIERRAMOD11CHECKDIGIT]"` and `fieldName: "OwningInstitutionItemId"` to double check it's in Recap and that we have the right barcode.
 2. Also check SCSB response for returned "owningInstitutionBibId" to determine if the SCSB bnum disagrees with the local Sierra bnum. If a mismatch is found, sync job should be processed as a "transfer". Otherwise it's a simple "update"
 2. Create a "transfer"/"update sync job using the Platform API's recap/sync-item-metadata-to-scsb endpoint.

## Setup

### Installation

```
bundle install; bundle install --deployment
```

### Setup

All config is in sam.[ENVIRONMENT].yml templates, encrypted as necessary.

#### Changes to SCSB/UAT endpoints

When HTC changes the SCSB endpoint, apply changes to the relevant deployment in `.travis.yml`. Both `SCSB_API_BASE_URL` and `SCSB_API_KEY` should be encrypted. Note that at writing a [dpl](https://github.com/travis-ci/dpl) bug impacting native ruby lambdas causes one's deployment config to fail to be applied. After deployment, check the deployed env variables to see if you need to manually apply changes.

## Contributing

### Git Workflow

This app uses a [Development-QA-Main](https://github.com/NYPL/engineering-general/blob/master/standards/git-workflow.md#development-qa-main) git workflow.

 * Cut branches from `development`.
 * Create PR against `development`.
 * After review, PR author merges.
 * Merge `development` > `qa`
 * Merge `qa` > `master`
 * Tag version bump in `master`

### Running events locally

The following will invoke the lambda against the sample event jsons:
```
sam local invoke --event event.[bib/item].json --region us-east-1 --template sam.[ENVIRONMENT].yml --profile [aws profile]
```

The sample `event.json` as follows:

### Gemfile Changes

Given that gems are installed with the `--deployment` flag, Bundler will complain if you make changes to the Gemfile. To make changes to the Gemfile, exit deployment mode:

```
bundle install --no-deployment
```

## Testing

```
bundle exec rspec
```

### Updating fixtures

Fixtures are stored in `./spec/fixtures`. Those ending in `.raw` are HTTP responses captured using `curl -is` as follows:

```
curl --http1.1 -is "https://platform.nypl.org/api/v0.1/items?nyplSource=sierra-nypl&bibId=10079340" -H "authorization: Bearer [**relevant access token**]" > ./spec/fixtures/platform-api-items-by-bib-10079340.raw
```

```
curl --http1.1 -is -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'api_key: [**scsb api key**]' -d '{"fieldName":"OwningInstitutionBibId","fieldValue": "10079340"}' 'https://[**scsb fqdn**]/searchService/search' > spec/fixtures/scsb-api-items-by-bib-id-10079340.raw
```

### Representative bibs/items

At writing, the following records serve as good representations of the many different scenarios this app understands:

 * Bib 16797396 has 1 item, which has a research Item Type (55), so listener should query by OwningInsitutionBibId (".b167973964") to identify the sole item (barcode 33433073119806) be synced.
 * Bib 10079340 has four items, the first of which has a research Item Type and rc* location, so SCSB will be queried to look up all four nested serial item barcodes to sync (barcodes "33433020768846", "33433020768838", "33433020768812", "33433020768820") * Item 11907243  has an 'rc*' location and should thus be pushed to scsb (as barcode 3343302076882)
 * Bib 17762923 is not mixed and has a circulating first item, so should not be processed
 * Item 11907244 (represented in `event.item.json`) has an 'rc*' location and should thus be pushed to scsb (as barcode 33433020768838)
 * Item 21558090 has a non-recap location, so should not be processed

## Deploy

Deployments are entirely handled by Travis-ci.com. To deploy to development, qa, or production, commit code to the `development`, `qa`, and `master` branches on origin, respectively.

