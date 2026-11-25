# BiletFlow

Flutter client for the BiletFlow API. The project targets Android and iOS; Flutter web is useful for previewing and testing the same flows.

## Implemented flows

- Registration, OAuth password sign-in, secure access/refresh token storage, session restoration, refresh, and sign-out.
- Account name and language updates, verification email requests and verification-token confirmation, and password-reset email requests.
- Public event browsing, ticket types, order creation, the backend's simulated checkout, purchased tickets, and QR rendering from the exact server payload.
- Organizer profile creation, managed events, event creation/editing, lifecycle actions, duplication, and ticket-type creation.
- Assigned check-in events, online camera scanning, exact QR-text entry, verify-only lookup, manual attendee search/admission, canonical admission results, registration/check-in counts, and server history.
- Check-in reversal with a reason and backend permission enforcement. Check-in staff can reverse their own recent admissions; managers and owners have wider access.
- Support cases with event/order/ticket context, categories, message threads, staff assignment/status controls, and escalation when permitted by the backend.
- English, Kazakh, and Russian language selection. New check-in, support, and account controls have translations; some existing attendee and organizer copy remains English.

All requests use lib/api_client.dart. Feature services provide endpoint-specific methods. Failed writes are not automatically retried after network errors. Check-in uncertainty requires checking the server state before another admission attempt. Backend errors and unsupported operations stay visible; there is no fabricated successful admission or demo record fallback.

## Setup

Use Flutter with Dart 3.13.2 or newer, an Android SDK, and JDK 21. This checkout was verified with Flutter 3.50.1/Dart 3.14.0, Android Gradle Plugin 9.1.1, and Gradle 9.3.1. Flutter selects the compatible Android SDK and NDK versions.

From this directory:

~~~powershell
flutter pub get
flutter run
~~~

The default API is https://biletflow-api.vercel.app/api/v1. Override it at build/run time:

~~~powershell
flutter run --dart-define=API_BASE_URL=https://your-api.example/api/v1
flutter build apk --release --dart-define=API_BASE_URL=https://your-api.example/api/v1
~~~

The API base URL is compiled into the app. Rebuild when changing it. An Android emulator reaches the development computer through 10.0.2.2; a physical phone needs an API address reachable from that phone. Use HTTPS for device builds. Flutter web also requires the API to allow the preview origin through CORS.

Camera access is requested when the user opens scanning. Android declares internet/camera permissions and makes camera hardware optional. iOS includes a camera usage description. Exact QR text entry remains available when a camera is unavailable or permission is denied. Internet access is required for admission; offline check-in is outside the SRS MVP.

## Checks and builds

~~~powershell
flutter test
flutter analyze --no-fatal-infos
flutter build web
flutter build apk --release
~~~

Flutter 3.50 reports informational deprecations for its legacy Material imports/localization delegates. The checked app has no analyzer errors or warnings. Migrating the UI package imports is a later SDK-maintenance task.

The Android APK is produced at build/app/outputs/flutter-apk/app-release.apk. The existing project signs release builds with the debug key for local academic demonstrations. Configure a private release keystore and a final application ID before store distribution. Do not commit signing secrets. iOS builds require macOS and Xcode.

## Presentation walkthrough

1. Use the web organizer tools to create/publish an event, add a ticket type, and assign a check-in staff account. Ensure accounts are verified where the backend requires it.
2. Register an attendee for that event. Open the attendee's ticket QR on a separate screen or printout. The app uses the backend's simulated payment flow; it does not charge a real card.
3. Sign in to the mobile app as the assigned staff member and open Check-in. Confirm that the assigned event appears.
4. Open the event and show registered/checked-in counts. Scan the QR or paste its exact BFT1 text. Confirm that the server reports admission and increments the checked-in count once.
5. Scan the same ticket again. Show Already checked in and the unchanged count. Verify-only lookup does not admit a ticket.
6. Search the attendee, open history, and reverse your recent admission with a reason. Show the restored count and retained admission/reversal records.
7. Show ticket QR, profile, organizer event management, and support threads as additional connected screens.

Before the presentation, test camera permissions and scanning on the actual Android phone, using the intended API and accounts. Browser preview verifies the UI and REST flow; it does not substitute for a native camera test. No physical Android device or iOS build was available during the automated checkup.

## Known backend dependency

The project checkup reproduced a backend refresh-token revocation gap: an older rotated refresh token can still be accepted after sign-out. Client sign-out clears local credentials and prevents late refresh responses from restoring the session. Backend code was deliberately left unchanged at the user's request; server-side revocation still needs a backend fix.
