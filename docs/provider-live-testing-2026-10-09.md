# Provider #37–#39: live verification, 2026-10-09

Tested by Codex with Shams's signed-in customer and provider test accounts on
the Pixel 8 Android emulator, using the normal debug apps and live Firebase
project `seer-8fd7c`. GPS was simulated near Mountain View. These results are
Android emulator checks, not physical-phone acceptance.

## Observed results

| Scenario | Result | Evidence |
| --- | --- | --- |
| Matching and available requests (#37) | Pass | Customer battery activation request reached the one nearby approved, available provider offering that service. The list showed the service, vehicle, address and existing deadline. |
| Location updates and distance (#37) | Pass | Moving provider GPS approximately 0.9 km updated `providers/{uid}.currentLocation` and changed the displayed distance from `0.0 كم` to `0.9 كم`. |
| Details (#38) | Pass | Service/option, bilingual Saudi plate, note, readable pickup address, distance, date/time and SAR 70 estimate were visible. Contact details were absent before acceptance. |
| Accept (#39) | Pass | Order `HYU5FQXN` changed to `accepted`, assigned the test provider and saved `acceptedAt=2026-10-09T16:14:05.138Z`. Provider opened the current-order tab; customer saw acceptance and its cancellation countdown. |
| Customer cancellation after acceptance | Pass | Customer confirmed cancellation through the app; Firestore was subsequently verified as `cancelled`. |
| Reject (#39) | Pass | Order `HDSXOXCZ` required confirmation, disappeared from available requests, and became `rejected`. One candidate and one matching `rejectedBy` entry; `providerId` remained null. Customer displayed the rejection banner and re-request button. |
| Expiry with customer force-stopped (#39) | Pass | Order `DOPHK1UQ` had `expiresAt=2026-10-09T16:26:51.753326Z`. After that deadline, provider details showed “هذا الطلب لم يعد متاحاً.” with no response buttons, and the list was empty. A server read still showed `pending` and no provider, proving removal did not depend on a customer write. |
| Customer recovery after expiry | Pass | Reopening the customer app and orders tab changed the expired request to `autoCancelled`; no current orders remained. |
| Customer review location correction | Pass | Replaced the fixed “لم يُحدد بعد” placeholder with the existing address card for the selected GPS point. Rebuilt/reinstalled the customer app and visually checked the readable address before sending the expiry request. |

The three live requests are identified by notes `SEER-QA-20261009-accept`,
`SEER-QA-20261009-reject`, and `SEER-QA-20261009-expiry`. Their final states are
respectively `cancelled`, `rejected`, and `autoCancelled`; no active test request
was left behind. Writes were made through the apps. Narrow read-only Firestore
queries confirmed the results. Simulated GPS was restored to its starting point.

Screenshots and narrow JSON evidence remain locally under
`/Users/shamsa/Documents/Codex/tmp/seer_*`; they are not committed because they
may include test-account details. Passwords and authentication tokens were not
collected.

## Automated checks and limits

- 22 provider request/location unit and widget tests passed.
- 25 isolated Auth/Firestore emulator tests passed against the proposed complete
  rules, including concurrent acceptance/rejection and access restrictions.
- Provider static analysis was clean and the normal debug APK built.
- After the customer review fix, its test passed and debug APK built; analysis
  reported only the same four existing `withOpacity` deprecation notices.
- The full provider suite still has the ten previously identified authentication
  test failures documented in `provider/docs/provider-requests.md`. This is not
  an all-suite pass claim.
- One Android “isn't responding” interruption occurred between live scenarios.
  The app ran normally after relaunch, and rejection/expiry completed afterward.
  No conclusive ANR trace was available on inspection; its cause is unresolved.
- Towing presentation was checked with the fixture preview; this live sequence
  exercised battery requests. Multi-provider races were tested in isolated
  Firebase emulators, not by sending live requests to other people's accounts.
- The proposed restrictive rules were **not deployed**. Current live rules still
  permit the anonymous reads used for this verification. Passing live workflows
  does not establish production authorization security. Review and deploy the
  complete `firestore/firestore.rules`, then repeat app compatibility checks;
  see `firestore-rules-review.md` for the known schema/privacy limits.

Before final team acceptance, repeat the scenarios on a physical Android phone,
including location permission denial and background/resume behavior.

## Pre-PR integration check

Merged `origin/main` at `eb776b6` (the AI assistant update) into the feature
branch without conflicts. After integration, all 52 customer tests and all 22
provider request/location tests passed. The Firebase emulator group was skipped
in this repeat run; its 25-test result above is from the earlier dedicated run.
The customer debug APK rebuilt successfully, and customer analysis still showed
only the same four deprecation notices. Live UI checks above preceded this merge.
