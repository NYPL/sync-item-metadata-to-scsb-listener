# Sync Item Metadata to SCSB Listener

This is a small Ruby app deployed as Kinesis Stream listener, sniffing for Bib/Item updates that should trigger syncing metadata to SCSB.

## Setup

### Installation

```
bundle install; bundle install --deployment
```

### Setup

All config is in sam.[ENVIRONMENT].yml templates, encrypted as necessary.

## Contributing

### Git Workflow

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
curl -is "https://platform.nypl.org/api/v0.1/items?nyplSource=sierra-nypl&bibId=10079340&limit=1" -H "authorization: Bearer [**relevant access token**]" > ./spec/fixtures/platform-api-items-by-bib-10079340.raw
```

```
curl -is -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' --header 'api_key: [**scsb api key**]' -d '{"fieldName":"OwningInstitutionBibId","fieldValue": "10079340"}' 'https://[**scsb fqdn**]/searchService/search' > spec/fixtures/scsb-api-items-by-bib-id-10079340.raw
```

## Deploy

Deployments are entirely handled by Travis-ci.com. To deploy to development, qa, or production, commit code to the `development`, `qa`, and `master` branches on origin, respectively.

