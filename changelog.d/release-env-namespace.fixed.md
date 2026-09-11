Release launchers now put caller-owned repository, announcement, identity, and
hosted-watch settings under `HARN_EXT_*`, so Harn's startup registry accepts
them instead of rejecting the wrapper's own environment before dispatch.
