A release refuses to mint its tag when main moved since certification. The tag
is minted on the release pull request's merge commit into main, not on the
frozen source, and publication reads the tag tree, so anything merged during the
cut shipped inside the version uncertified. The merged commit's tree must now
equal the certified candidate's tree; a mismatch names the drifted paths and
tells the operator to re-dispatch at the new commit, which re-certifies. There
is no override: a freeze was the only thing standing between a moving main and
an uncertified release, and a convention is not a gate.
