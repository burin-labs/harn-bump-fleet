`release_harn` now serializes live owner acquisition with an atomic Harn filesystem lock so duplicate release lanes cannot race through owner-record creation.
