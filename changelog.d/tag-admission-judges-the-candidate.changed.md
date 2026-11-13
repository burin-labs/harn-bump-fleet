Moved the tag-time admission from the whole commit range onto the release
candidate: the tip that would carry the tag. What ships is a tree, not a
sequence, and the tag names one commit that consumers pin, so the branch's
verdict on that exact content is the question worth asking. Every earlier
commit in the range is already contained in it.

The old rule refused on any commit in the range with a failing or unsettled
required check. Under fix-forward, where a red is corrected by a later commit
rather than by reverting the red one, such a commit is always on the branch, so
the rule refused every cut forever while the tree it refused had a green
aggregate. It also held the branch to a stricter bar than the branch holds
itself.

Earlier commits stay in the receipt as history and any that did not pass are
named there, so a repaired range and a clean one no longer produce the same
text. A red candidate still refuses, a candidate absent from the commits whose
checks were read still refuses, and the non-required lanes a release proceeds
over are still named.
