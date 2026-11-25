# Scheduled orders — implementation handoff

Source: user-uploaded `Seer--main (7).zip`. These changes are made in a separate copy, not in the original ZIP or GitHub.

## Customer
- Original horizontal service cards and the immediate-order form are unchanged; an optional immediate/scheduled radio choice appears inside `RequestServicePage` after the location section.
- Scheduling is restricted to today's and tomorrow's local dates. A bottom-sheet Cupertino wheel picker provides 12-hour time (AM/PM) and five-minute increments across the full day, with only future times allowed. Date/time validity is rechecked when confirming the picker and again when submitting the order. The requested time means **provider arrival**, not dispatch time.
- `scheduledAt` is a Firestore Timestamp. New status is `scheduledPending`; provider confirmation transitions to `scheduledAccepted`.
- Scheduled orders do **not** use the immediate-request 2-minute expiration; notification expiration is the arrival time.
- The customer sees the appointment in their existing Orders list and details. A scheduled order can be cancelled while `scheduledPending` or `scheduledAccepted`, and cannot be cancelled after `onTheWay`.
- Cancelling an accepted booking notifies the assigned provider and releases their reservation.

## Provider
- Scheduled bookings are offered to approved, non-suspended nearby providers whether or not `isAvailable` is currently true. The existing 5-km distance/service eligibility logic is reused; `currentLocation` must exist.
- The existing Orders page adds a `المجدولة` tab containing incoming scheduled requests and confirmed bookings. The existing immediate request, current-order, and history tabs remain.
- Provider acceptance uses the existing Firestore acceptance transaction and customer notification, but does not set `activeOrderId` until the provider starts driving. This keeps future bookings from consuming the live-order slot.
- Bookings within 2 hours of an already accepted booking for the same provider are rejected atomically using `scheduledReservationTimes` on the provider document.
- On/after 12 hours before arrival, `بدأت التوجه للعميل` transitions atomically from `scheduledAccepted` to `onTheWay`, checking `activeOrderId`. The existing `onTheWay → arrived → inProgress → completed` flow is reused.
- Completing an order releases its reservation, and admin suspension cancels outstanding scheduled bookings along with existing open orders.

## Important constraints / tests needed
- **Flutter SDK is not available in this execution environment**: `flutter analyze`, Flutter unit/widget tests, emulator tests, and Firebase integration tests have **not** been run. Run them on a development machine before merging.
- The 12-hour boundary is enforced inside a **client-side transaction** using the device clock; robust trusted-time enforcement across closed clients needs server-side enforcement. No Firebase functions, deployed rules, or billing changes were made.
- Unaccepted scheduled requests expire when the customer app is open (or reopened); guaranteed unattended automatic expiry/activation needs a scheduled backend job. Accepted bookings do not automatically mark a provider `onTheWay`; the provider must start the journey.
- Reservations use two hours as a conservative collision window. This is a policy assumption that can be adjusted; distance/travel-time feasibility is not proven.
- Providers who have never saved `currentLocation` will not be matched, even if they are approved; this retains the original location eligibility rule.
- Actual provider arrival at exactly the selected time is **not guaranteed**. Text presents the appointment as requested arrival time.
- Firebase deployed rules have **not** been modified. Check integration with the rules your team actually deploys.

## Suggested smoke tests
1. Immediate order still follows the existing 2-minute deadline and acceptance flow.
2. Schedule for today and tomorrow; already-passed times and dates after tomorrow are rejected. Check 11:55 PM and reopening the picker after its selected time passes.
3. Currently unavailable but approved provider within 5 km sees the scheduled booking; suspended provider does not.
4. Provider accepts: customer sees provider; provider remains able to accept immediate jobs (subject to existing active-order lock).
5. Second booking within 2 hours for same provider fails; booking at non-conflicting time succeeds.
6. Customer cancels accepted booking: provider receives cancellation, booking disappears, reservation is released.
7. Provider attempts `On the Way` before 12 hours: rejected; within 12 hours: succeeds; if another live order exists: rejected.
8. After `On the Way`, customer cancellation is blocked; `arrived → inProgress → completed` continues as normal.
9. Admin suspension cancels unstarted scheduled bookings and releases reservations; it does not cancel in-progress work.
10. Compare both apps' notification and order models and run full existing test suites.
