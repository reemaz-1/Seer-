# Admin dashboard — US#82–85

The first page after admin login shows live counts from `customers`, `providers`, `orders`, and `complaints`.

- **US#82:** total customer accounts, provider accounts (with approved count), and requests.
- **US#83:** requests grouped by `serviceCategoryId`, including car washing. Unknown categories remain visible as “خدمة أخرى”.
- **US#84:** pending and resolved complaints. Compensated complaints are part of resolved, not another status. Resolution without compensation is not labelled rejection.
- **US#85:** loyalty and compensation washes granted, plus used/reserved washes. Loyalty matches the customer app: one wash per five completed, non-free services **per customer**. Cancelled, rejected and auto-cancelled free orders return the reward.

The layout follows the shared dashboard reference. It also shows seven-day order history, scheduled request counts and rated providers. Existing registration, users and complaints pages remain accessible; narrow screens use a drawer.

## Data and periods

`DashboardModel` streams the four collections and waits for every first snapshot. `DashboardController` calculates statistics and handles period selection, errors and listener cleanup. `AdminHome` renders the results.

Account totals and provider rankings always cover all records. The period filter applies to order/complaint creation dates, compensation grant dates, each customer's fifth paid completion, and free-wash reservation dates. The daily chart always shows the latest seven calendar days. Undated records remain included under “كل الفترات”; periods do not substitute creation time for an unknown completion date.

The dashboard never writes records. It labels cached data and offers retry on failure rather than silently displaying zero. No order fields or customer/provider contracts are changed. For the current project size, aggregation is performed in the admin client from four collection listeners.

## Verification

From `admin`:

```sh
flutter test
flutter analyze lib/controllers/dashboard_controller.dart lib/models/dashboard_model.dart lib/views/home.dart lib/views/admin_main.dart test/dashboard_test.dart test/dashboard_model_test.dart
flutter build web
```

From `firestore/tests` (Java required):

```sh
npm ci
npm test
```

Automated tests cover per-customer reward thresholds, free-wash refunds, service grouping, period boundaries, empty data, errors/retry, snapshot readiness, stream cleanup and the complete admin shell at widths 320 and 1200. Rules tests allow trusted admins to list the dashboard collections while rejecting non-admin order listing, role self-provisioning and unrelated admin order writes.

The rules change is a review candidate: add `isAdmin()` to the existing `orders` read condition in the deployed rules after team review. Do not replace live rules with this repository file without reconciling the team's other rules changes. No live Firebase rules were deployed. Browser layout verification uses synthetic data; authenticated production-data verification remains pending.
