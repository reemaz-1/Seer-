# Firestore rules review — 2026-10-09

## Source and scope

Shams supplied the currently published rules from Firebase Console. Their only
grant is `allow read, write: if request.time < timestamp.date(2027, 1, 31)` under
`match /{document=**}`. This permits anonymous reads, edits and deletes until
2027-01-31 00:00 UTC (03:00 Riyadh), then denies all client access. Adding narrower
matches cannot restrict that grant: matching `allow` expressions are ORed.

`firestore/firestore.rules` is a complete replacement **for team review**, covering
the operations present in the current customer, provider and admin code. It has
not been deployed. `provider/firestore/provider_requests.rules` remains a scoped
test fixture and must not be published as the complete application rules.

| Data | Permitted client access |
| --- | --- |
| admins | Each signed-in user can check their own role; no client can create/edit/delete admin roles. Provision through a trusted console/server. |
| lookup_data | Public reads of vehicles and service_prices for registration/catalogue; no client writes. |
| customers | Own registration/profile access; admin can list/read customers. |
| customers/{uid}/vehicles | Owner CRUD with the current vehicle fields. |
| providers | Own registration as unverified; verified-email submission to pending; admin pending→approved/rejected only. Owner profile edits cannot alter approval, role, rating or creation metadata. |
| provider matching | Approved, email-verified owners update their GPS/availability; customers can query approved providers. |
| orders | Customer creates own pending orders and reads their own history; approved candidates/assigned provider read their requests. No deletes or arbitrary edits. |
| order responses | Exact provider acceptance/rejection checks, timestamps and deadlines from #37–#39. |
| existing order lifecycle | Customer cancellation/expiry; assigned provider sequential progress, payment completion and own aggregate statistics. |
| other paths | Denied. |

## Deliberate compatibility limits

- Firestore reads entire documents. The existing matching query and assigned
  provider summary read `providers` directly, so customers with profiles can
  read all fields of approved providers, including nationalId/licenseNumber and
  currentLocation. Restricting that to public matching/profile fields requires
  a separate public document or trusted matching endpoint. No schema change was
  made without the team's agreement. Candidate order reads likewise include
  customer contact fields even though the pre-acceptance UI hides them.
- Matching and estimated-price calculation remain client-side, as in the current
  app. These rules prevent later tampering with those order fields, but do not
  independently certify candidate membership by service/distance, copied profile
  text, or initial prices. Authoritative matching/pricing needs backend work.
- The existing customer app writes server createdAt but calculates expiresAt
  from the phone. Creation permits a future expiry up to server time +135 seconds
  (the intended 120 seconds plus 15 seconds of positive clock skew). Large clock
  errors are rejected; acceptance uses the saved expiry and server request time.
  Exact server-created two-minute deadlines require changing order creation.
- Existing provider completion allows nullable finalPrice and uses the phone's
  local completedDay. These are preserved; completedAt must be server time.
- There is no blanket admin order-write permission. The current admin app manages
  provider approvals and user lists; add future admin actions with explicit tests.
- Since previous rules permitted anyone to edit admins and provider approvals,
  verify the existing admin UIDs and approvals with the team before publication.
  The new rules prevent future client role writes, but cannot certify old data.

## Repeatable isolated verification

Result on 2026-10-09: **25 emulator tests passed** (the 15 provider request/race
tests plus 10 complete-app access scenarios). Provider static analysis is clean.
The suite closes idle Firestore web channels between scenarios to avoid Chrome's
per-host connection limit across its independent test-user sessions.

From the repository root, start Auth/Firestore emulators with a disposable project:

```sh
firebase emulators:start --only auth,firestore \
  --project demo-seer-requests --config firebase.rules-review.json
```

From `provider/`, run the real provider repositories and compatibility payloads:

```sh
flutter test --platform chrome \
  --dart-define=RUN_REQUEST_EMULATOR_TESTS=true \
  --dart-define=RUN_FULL_RULES_TESTS=true \
  test/requests/request_transactions_emulator_test.dart
flutter analyze
```

All tests use emulator hosts and a hardcoded `demo-` project. Customer
registration/cancellation/query payloads match the inspected customer code; this
is not a claim that all three apps were manually tested against production.

## Publication handoff

After team review, copy the complete contents of `firestore/firestore.rules` into
the project's Firestore Rules editor, **replacing** the expiring wildcard grant.
Confirm the project is `seer-8fd7c`, review the editor diff, then Publish. Do not
append the rules below the old grant. A trusted maintainer can alternatively run
`firebase deploy --only firestore:rules --project seer-8fd7c --config firebase.rules-review.json`
from the repository root after approving the exact file. No deployment was run
by this task. Test customer registration/order creation, provider approval/GPS,
accept/reject/cancel, and completion in the three real apps after publishing.

References: [overlapping rules](https://firebase.google.com/docs/firestore/security/rules-structure),
[field access and whole-document reads](https://firebase.google.com/docs/firestore/security/rules-fields).
