A failed release now names the repair for the precondition that actually
refused. The launch preflight's receipt already listed which of its questions
failed, but nothing read it, so an escalation could only offer the repair for
the whole step. The finalizer reads the receipt and hands those names to the
registry's repair map. A run that failed before the preflight wrote a receipt
reports no cause named, which is not read as a preflight that passed.
