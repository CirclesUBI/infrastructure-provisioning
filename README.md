# Infrastructure & Services [![Chat Server](https://chat.joincircles.net/api/v1/shield.svg?type=online&name=circles%20chat)](https://chat.joincircles.net) [![Backers](https://opencollective.com/circles/supporters/badge.svg)](https://opencollective.com/circles) [![Follow Circles](https://img.shields.io/twitter/follow/circlesubi.svg?label=follow+circles)](https://twitter.com/CirclesUBI) [![Circles License](https://img.shields.io/badge/license-APGLv3-orange.svg)](https://github.com/CirclesUBI/infrastructure-provisioning/blob/master/LICENSE)

Circles is a blockchain-based Universal Basic Income implementation.

[Website](http://www.joincircles.net) // [Whitepaper](https://github.com/CirclesUBI/docs/blob/master/Circles.md) // [Chat](https://chat.joincircles.net)

## Manually Deployed Resources

- iam users
- terraform state buckets & dynamodb tables

## Secrets

Sensitive information is stored in a keepass file outside of git and must be placed in a per module `terraform.tfvars` file.

## Deploying From Scratch

There is a dependency ordering between the modules in this repo, and if deploying against a fresh account you should do so in this order:

1. `circles-vpc`
1. `circles-cognito`, `circles-sns`
1. `circles-api`, `circles-website`
1. `circles-website`, `cafe-grundeinkommen-website`
