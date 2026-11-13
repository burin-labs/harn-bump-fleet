A pull request is no longer refused for another repository's state. The release
preflight still asks every precondition and still records each one, but on a
pull request an unfolded release or a drifted consumer adapter is announced as
a warning rather than failing the check, because no commit in this repository
repairs either. Pushes to the default branch, the hourly run, and the release
itself keep refusing on all of them.
