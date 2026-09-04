The hosted release watcher now stores its refreshed GitHub CLI login under the
runner's already-confined secret scratch directory. Publication recovery no
longer loses access to the credential while importing the durable release
receipt.
