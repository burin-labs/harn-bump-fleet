- Serialize release-watch receipt transitions, warm-cache dispatch, queue restoration,
  and ref cleanup under one cancellation-safe host lease so duplicate local watchers
  cannot race into duplicate recovery workflows.
