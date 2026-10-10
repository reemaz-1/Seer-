# Provider requests (#37, #38, #39)

## Behaviour

Open **الطلبات → المتاحة** in an approved provider account. Requests come from
`orders` using `candidateProviderIds arrayContains currentUid`. Only the shared
`pending` / unassigned / not-declined / future-`expiresAt` subset is displayed.
The status filter is deliberately local, so this query needs no composite index.
Customer `MatchingController` supplies those candidate ids only after checking
`servicesOffered[categoryId].options[optionId].enabled`, approved/available status,
and a currentLocation within its existing 5 km matching radius. We preserve this
contract rather than maintaining a conflicting service-matching algorithm.

A one-second controller timer removes expired requests without waiting for a
Firestore write. Missing deadlines fail closed. Returning to the screen uses the
same absolute deadline, never a new two-minute response window.

Details show service/category option, vehicle and bilingual Saudi plate, note,
readable pickup address (and towing drop-off), distance from foreground GPS,
formatted date/time and price. Towing explicitly labels the estimate as the base
price excluding distance fees. Location denial/failure leaves requests usable,
shows an Arabic error, and lets the provider retry GPS from the location button.
The user also authorized provider-location integration: turning availability on
first obtains GPS and saves the existing `providers/{uid}.currentLocation` as a
GeoPoint, then sets `isAvailable=true`. Opening the requests tab refreshes that
point and writes foreground GPS movement updates (ten-metre filter), so future
customer matching uses the provider's position. Turning availability off needs no
GPS permission. Only `currentLocation` is changed by the location gateway.

Accept has a shrinking light fill and a tabular `m:ss` countdown. It is a Firestore
transaction that rereads eligibility and writes exactly `status=accepted`, the
current `providerId`, and server `acceptedAt`. A successful acceptance opens the
existing current-order tab. Reject first asks for confirmation; its confirmation
button also disables if the order expires while the dialog is open. A rejection
transaction uses `arrayUnion(currentUid)` and sets `rejected` only once all
candidate ids have declined. The provider never writes `autoCancelled`.

A transaction can fail on permission checks before a concurrent rejection's
version conflict is reported. Rejection retries that failure once in a new
transaction, rereading all conditions and preserving the strict rules. Stale
request results are returned from SDK transaction callbacks, then converted to
our domain error outside the callback so native and browser SDKs behave alike.

No additional order fields were introduced. `customer/lib/models/order.dart`
and `provider/lib/models/order.dart` are identical, with a regression test that
checks their full contents. Existing current-order/payment/statistics operations
moved unchanged to `models/provider_order_model.dart`; their two controllers use
that gateway. Request business logic lives in `ProviderRequestsController`,
Firestore operations in `ProviderRequestModel`, GPS in `ProviderLocationService`,
and Arabic presentation in the request views/widgets.

## Firebase rules: remaining deployment dependency

`firestore/provider_requests.rules` is a **reviewable scoped rules file**, used
by the new local test configuration. It is not the full application's deployed
rules and MUST NOT replace them as-is. It only covers provider request reads/responses and the owner currentLocation update; it does not grant customer creation/cancellation, admin access or
provider current-order/payment updates from the other stories.

Shams has now supplied the production rules: they allow anonymous reads/writes
until 2027-01-31. They do not enforce the provider restrictions below. A complete
replacement for the current three apps is prepared at
`../../firestore/firestore.rules`; see `../../docs/firestore-rules-review.md` for
compatibility limits, tests and publication instructions. The Firebase CLI has
no authorized account here, and the replacement has NOT been deployed. Do not
leave the broad expiring grant alongside it: that would bypass the restrictions.

Checks enforce an approved provider with a verified email, candidate membership,
unassigned pending status, a server-time deadline, and only the specified fields.
An acceptance must assign the caller and use `acceptedAt == request.time`.
Rejection may only add the caller, never remove previous ids or reject on another
provider's behalf. Non-candidates cannot read or alter these requests. Candidate
reads include later status changes so open details retire promptly.

Customer name/phone are **hidden in the pre-acceptance UI**. Because the team
stores them on the same readable order document, this is not field-level privacy:
Firestore reads whole documents. Real pre-acceptance contact secrecy would need
a separately protected document/schema design agreed with the team first.

## Validation

Verified on 2026-10-09: provider analysis has no issues; 22 request/location
unit and widget tests pass, and 25 Auth/Firestore emulator tests pass against
the complete proposed rules (15 request tests plus 10 application access tests). The
feature suite skips its emulator group unless explicitly enabled below. The
full provider suite still reports the same 10 pre-existing auth failures.
The fixture preview was checked on the Pixel 8 Android emulator for the list,
towing details, bilingual plate, addresses, base-price notice, shrinking
countdown and rejection dialog.
The normal `lib/main.dart` debug APK builds successfully and was installed on
Pixel 8 after the fixture preview. Real customer/provider account testing on
Pixel 8 against the live Firebase project is recorded in
`../../docs/provider-live-testing-2026-10-09.md`. These functional checks use the
currently published rules; deployment of the proposed security rules and
physical Android device acceptance remain separate requirements.

From `provider/`:

```sh
flutter pub get
flutter analyze
flutter test test/requests
flutter build apk --debug
```

Start isolated emulators (Node, Java and Firebase CLI required):

```sh
npx firebase-tools@14.27.0 emulators:start --only auth,firestore \
  --project demo-seer-requests --config firebase.requests-test.json
```

In another terminal, exercise the **real Dart repository** and scoped security
rules using three independent authenticated emulator sessions:

```sh
flutter test --platform chrome --dart-define=RUN_REQUEST_EMULATOR_TESTS=true \
  test/requests/request_transactions_emulator_test.dart
```

Tests cover winner-only concurrent acceptance, concurrent/sequential final
rejection, foreign orders, forbidden field edits, server timestamps, wrong clocks,
cancelled/expired requests, approval checks and owner-only location updates. Their hardcoded `demo-` project
uses Auth on 9199 and Firestore on 8180, and never imports production options.
Test accounts/documents live only in the disposable emulator process.

Local visual preview (fixture data only, no Firebase):

```sh
flutter run -d <android-device-id> -t tool/preview_requests.dart
```

The preview is explicitly labelled as test data. For the real app, run
`flutter run -t lib/main.dart` or rebuild the normal APK; do not distribute the
preview APK. Physical-device acceptance testing remains separate from automated
unit/widget, Firebase emulator and Android emulator verification.

At the starting main revision `63eb8df`, the existing provider auth suite already
had 10 failures (one old pending/unverified expectation and nine unmocked Firebase
view dependencies). Those authentication stories are outside #37–#39.
