# Security policy

## Reporting a vulnerability

Email **security@harn.cloud** with the details. Encrypt with our public key
if the report contains exploit material (key available on request).

Please include:

- a clear description of the issue and the impact (e.g. arbitrary code
  execution during `harn install`, malicious bump PR auto-merged into a
  downstream repo, leaked App credentials)
- a minimal reproduction
- any affected versions of the install script, bump workflow, or pinned
  dependencies
- whether the issue has been disclosed publicly or to other parties

## Response window

We aim to:

- acknowledge new reports within **2 business days**
- triage and confirm (or dispute) within **5 business days**
- ship a fix or mitigation within **30 days** for confirmed issues, faster
  for actively-exploited supply-chain bugs

## Scope

In scope:

- `scripts/install_harn.sh` and its integrity-verification logic
- `.github/workflows/bump-harn.yml` (auto-bump cron), its immutable Harn setup
  action pin, and the App identity it pushes under
- the pinned `harn-github-connector` dependency and the lockfile
- any vector that lets an attacker forge a Harn version bump PR or push
  unsigned code into downstream repos via this fleet

Out of scope (report to the appropriate upstream):

- vulnerabilities in `harn` itself ->
  https://github.com/burin-labs/harn/security/policy
- vulnerabilities in `harn-github-connector` ->
  https://github.com/burin-labs/harn-github-connector/security/policy

## Coordinated disclosure

We support coordinated disclosure. Please give us the response window above
before publishing details. We will credit reporters in the release notes for
the fix unless asked otherwise.
