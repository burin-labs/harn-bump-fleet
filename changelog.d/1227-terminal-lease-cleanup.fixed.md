An explicitly disabled Harn release candidate now releases its exact owned
merge lease after the queue is restored. Recoverable publication failures keep
their lease, and another release generation's lease is never deleted.
