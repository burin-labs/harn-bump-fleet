The release preflight now asks what has to be true before anything is tagged:
the branch carries the exact next development version, the release contract is
green on that commit, the tree that will carry the tag holds no unfolded
changelog fragment, and every consumer's pin is known by value. Each is a typed
precondition in the same receipt, and a pin that could not be read is named
rather than counted as converged.
