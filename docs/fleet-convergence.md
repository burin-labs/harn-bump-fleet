# Fleet convergence contract

The hosted bump workflow is one bounded convergence controller, not a version
search-and-replace bot. It reconstructs its state from the released Harn tag,
each consumer's default branch, the canonical automation branch, open pull
requests, and exact-head CI receipts.

Its loop has four semantic phases:

1. The reusable Harn bump workflow performs deterministic pinning, generated
   projections, registered codemods, and repository-owned refresh commands.
2. The controller presents an exact signed target branch if publication
   succeeded but the producer's immediate branch comparison falsely reported
   a no-op. This recovery is leased by the observed branch head and spends no
   model tokens.
3. Failing downstream validation admits a manifest-owned checkout and validator
   to the value-model repair loop. The model may inspect and edit tracked files;
   deterministic validation, signed publication, the branch-head lease, and
   auto-merge remain connector-owned effects.
4. The controller observes downstream CI again and, when the first semantic
   migration was incomplete, performs one more bounded repair cycle before the
   final convergence proof.

Routine releases therefore stay deterministic and cheap. Breaking Harn
language or runtime changes get up to four agent attempts across two CI-fed
cycles, using the shared `HARN_FLEET_REPAIR` planner defaults. Each cycle has a
USD 0.25 cost ceiling in hosted automation, exact repository and head scope,
two local validation attempts, and persisted transcripts/JSON receipts. The
workflow remains red unless every selected consumer reaches the target on its
default branch.

The controller deliberately refuses drafts, conflicts, unknown heads, missing
validators, unrelated branches, and target branches whose pin does not satisfy
the requested release. Those are authority or ownership failures, not prompts
for a model to improvise around.
