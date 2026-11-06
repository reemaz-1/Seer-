# Customer order-status Push (#28)

This code adds real Android Firebase Cloud Messaging delivery after Home, screen lock, or removing the app from Recents. A server order-update trigger sends an FCM **notification payload**; it does not require a live Dart/Firestore listener on the customer's phone. The existing inbox and foreground banner remain, without posting a second local notification for the same background event.

**Prepared for review; not deployed. No Firestore rules are published by this change.**

## What is included

- `registerCustomerPushToken`: authenticated callable, verified active customer only. Token ownership comes from Firebase Auth, not a client-supplied UID. Global hashed token ids reassign an installation when accounts change; token rotation cleans up the previous owned token.
- `sendCustomerOrderStatusPush`: order-update trigger, canonical inbox id per status, delivery lease and retry state, per-device partial retries and removal of invalid tokens. FCM notification tags make redelivery replace the same order/status row. Trigger delivery is at least once; a crash between sending to FCM and saving the result can still redeliver the same tag.
- Android channel, icon and permission request. Cold-start and background notification taps open the order only for the signed-in customer. Web/iOS are not configured for push in this Android project.
- Client token registration retries on resume if the callable was temporarily unavailable. Logout deletes the installation's FCM token; the app never navigates to a notification for another account.

## Before production activation

1. Use **Node 22**, and run `npm ci && npm test` in `functions/`.
2. An authorized Firebase operator must verify the project supports Cloud Functions deployment and that the FCM API is enabled. No billing plan changes were made here.
3. `customerPushTokens` contains FCM installation tokens and **must deny all client reads/writes**, including authenticated clients. `customerPushDeliveries` must also be server-only. The proposed complete `firestore/firestore.rules` already denies unmatched collections, but the repository file does not prove what is deployed. **Do not activate these functions while the project's open test-mode rule grants access to these collections.** Confirm protection with the team; this work does not publish or change deployed Firestore rules.
4. Check the callable and client both use `us-central1`, or change both together before deployment.
5. Sign in to the intended Firebase account. Review these exact functions before publishing.

Only after the operator completes those checks, this functions-only configuration can be used:

```sh
firebase deploy --config firebase.push.json --project seer-8fd7c \
  --only functions:customer-push
```

Run that command from the repository root. It is documentation for the operator, **not a command run by this change**. `firebase.push.json` intentionally has no `firestore` section. Do not run an unscoped `firebase deploy`, and do not publish Firestore rules as part of enabling push.

## Real-device acceptance

Use the new Android build and allow notifications. Sign in as a verified customer and confirm `registerCustomerPushToken` completes before testing:

1. Request and accept a service with another provider account. In the foreground, verify one in-app banner with the phone's normal/vibrate/silent behavior.
2. Press Home, then advance the order. Verify a phone notification and tap it to open the correct order.
3. Lock the screen and advance it again. Verify the lock-screen notification.
4. Remove the customer app from Recents, advance the order, then tap the notification. Verify cold-start navigation after the customer session/role check.
5. Log out or switch accounts, then verify an old account's notification cannot open its order in the new session.
6. Complete the service and confirm the rating action is available after opening its notification.

Android's **Force stop** from system settings is different from swiping Recents: Firebase documents that delivery resumes only after the user manually reopens a force-stopped Android app. No implementation can promise delivery against that OS control. See [Firebase receive-messages guidance](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages).

The local tests simulate messaging and token lifecycle. They do not prove production FCM delivery, notification permission state, OEM background restrictions, or a physical-device result. Firebase CLI currently has no authorized account in this workspace, and neither function has been deployed here.
