# Candidate record

A release candidate has one archive identity after certification. The candidate
record is the authenticated view of that identity used by every later release
stage.

## Why it exists

Release archives are not reproducible byte for byte. Two workflow runs can build
the same candidate under the same policy and still produce different binaries.
The candidate commit therefore cannot tell a recovery run which archive was
certified.

Earlier recovery accepted an archive run ID plus a hosted-run artifact containing
a receipt. Those values duplicated the certification's decision and could
disagree with its durable record. The disagreement check prevented substitution,
but the parallel input path still made operators reconstruct state the release
system already owned.

## Authoritative identity

Certification creates one signed annotated tag at
`refs/tags/harn-candidate-archive-certification/<candidate-oid>`. Its payload is
the existing closed `release_harn.candidate_archive.v1` receipt. Reading the tag
produces a `CandidateRecord` with:

- the candidate source OID from the verified tag target;
- the immutable attempt ref from the signed receipt;
- the archive workflow run and digests from that receipt;
- the certification ref and annotated-tag object OID from the authenticated Git
  read.

The tag name is write-once for a candidate. A retry may reuse it only when every
receipt field is identical. A moved ref, wrong target, invalid payload, or
untrusted signature fails closed.

## Lifecycle

The first certification run may use its workspace receipt before the signed
record exists. The successful certification join writes the record. Every later
recovery reads that record directly, then proves its selected archive artifact is
still present, unexpired, source-qualified, and built under matching policy.

No hosted workflow input or release CLI flag can select a different archive. If
the record is absent during initial certification, the archive gate may build a
new archive. If a record exists, its archive identity is the only admissible
choice.

## Next ownership slices

This cut removes parallel archive selection. The remaining release-chain work
moves post-publication sequencing into the typed reducer, then moves candidate
through tag ownership behind the same state machine. Each slice must delete the
old decision edge when the new owner becomes authoritative.
