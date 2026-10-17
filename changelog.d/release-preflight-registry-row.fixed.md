The hosted release failure registry named a step the workflow no longer has and
did not name the release launch preflight that replaced it, so the check that
keeps the registry in step with its workflow refused every branch. The row is
substituted, and its repairs are keyed on the preflight receipt's own
preconditions, since one step asking many questions has one repair per question
rather than one for the step.
