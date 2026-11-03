A dropped HTTP request to a consumer's gate workflow no longer fails a release.
Transport failures and 5xx responses now retry with bounded backoff, five sends
over about two minutes, and every attempt is recorded on the gate receipt. Only
after the bound is exhausted does the gate report itself unreachable, naming the
last error. A refusal the remote actually answered is still reported on the
first send rather than retried.
