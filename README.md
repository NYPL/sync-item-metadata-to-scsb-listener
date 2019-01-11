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

## Deploy

Deployments are entirely handled by Travis-ci.com. To deploy to development, qa, or production, commit code to the `development`, `qa`, and `master` branches on origin, respectively.

