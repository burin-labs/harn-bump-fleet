# Harn update language

This repository keeps Harn releases moving into the repositories that use
them. These are the primary terms in code, receipts, workflows, and operator
documentation.

- **Harn update**: moving one repository to a released Harn version and proving
  the result on its default branch.
- **Update run**: one bounded attempt to update a selected set of repositories.
- **Hosted round**: one resumable slice of an update run under fresh
  short-lived GitHub credentials.
- **Update proof**: the exact pull-request head, green checks, merge commit, and
  default-branch evidence that make an update complete.
- **Repair attempt**: one model-assisted source change followed by the
  repository's deterministic validator.
- **Value route** and **strong route**: the normal and escalated model classes.
  Escalation needs evidence that the cheaper route made no progress.
- **Repository budget**: the attempts, tokens, dollars, and time available to
  one repository. One difficult repository cannot consume another's budget.
- **Run budget**: the outer ceiling across every repository in one update run.

“Fleet convergence” remains only as a compatibility name in old schema IDs or
entry points while callers move to this language. New user-facing text and new
public symbols use the terms above.
