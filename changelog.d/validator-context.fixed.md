Fleet repair now gives each consumer validator an exact Harn release target and
private scratch directory instead of inheriting empty runner variables. Invalid
targets and scratch paths outside the repair workspace are refused before the
validator starts.
