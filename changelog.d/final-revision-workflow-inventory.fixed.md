Release certification now reads its workflow and job inventory from the exact
main commit being admitted or tagged, so a job added while a pinned release is
running cannot be omitted by the watcher's frozen checkout.
