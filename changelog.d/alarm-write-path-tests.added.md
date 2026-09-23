Cover the pin-staleness alarm's issue open, refresh, and close path with
offline HTTP-mocked tests, including the refusal cases where a failed write or
a failed probe must be reported rather than read as "nothing to do".
