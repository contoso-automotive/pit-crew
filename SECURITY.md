# Security policy

Pit Crew is a teaching app with synthetic data only. It holds no real customer, vehicle or payment data.

## Report a vulnerability

Use **Report a vulnerability** on this repository's **Security** tab, which opens a private advisory. Please don't open a public issue for a security problem.

## What we do

- GitHub Actions are pinned to full commit SHAs, and Dependabot keeps them, the npm packages and the container base image current.
- Every workflow starts with a read-only `GITHUB_TOKEN` and asks for more only in the job that needs it.
- Azure access uses OpenID Connect and managed identities. No Azure password, key or connection secret is stored in this repository.
