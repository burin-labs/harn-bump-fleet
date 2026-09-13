The typed release watch result now names which question it answered: whether
the release candidate was admitted onto main (`main_tag_admission`, decided
before any merge exists), or whether the commit that already landed may have
the tag minted on it (`tag`, decided once a merge SHA exists). The phase is
derived from whether a merge commit exists yet, never chosen per action, and
is carried through the JSON result and the operator-facing pending/failed
line. A refusal that stopped a release before it merged used to print under
the same generic "main tag" label as a refusal to mint the tag on an
already-merged commit, and a reader could not tell the two apart without
reading the reason text closely.
