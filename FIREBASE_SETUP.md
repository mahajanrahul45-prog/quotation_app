# Online quotation workspace

## Offline access and login changes (11 October 2026)

Login navigation regression: changing the MaterialApp key while preserving a
global Navigator key could retain the old login route after the account profile
was loaded. The app now keeps MaterialApp stable and creates a fresh navigator
for session changes. Login passes the signed-in UserCredential user directly
through account verification and awaits the workspace handoff. A widget test
verifies that a delayed currentUser/auth event still reaches Business overview.

Existing accounts reuse their verified, account-scoped access metadata when
opening the app. The account listener refreshes permissions in the background;
server-reported missing, disabled, or denied accounts still block access. New
accounts must connect once to sign in and download their workspace. Keep the
session signed in to work offline; clearing browser/device storage removes the
offline copy.

Edits are saved locally in the durable outbox before cloud upload. Sync retries
every 20 seconds while the app is running, with bounded transaction retries.
Conflicting edits remain available for the user to resolve. Browser-restored
cloud images use data URLs instead of filesystem paths. Web bootstrap registers
the generated Flutter service worker; build with
`flutter build web --pwa-strategy offline-first` and serve over HTTPS (or localhost). Test offline reopening on the
actual deployment, including Firebase SDK resources, before relying on it.

The Firebase CLI credential available on 11 October had expired. Live backend
verification/deployment requires `firebase login --reauth` by the owner. These
changes do not alter Firestore access rules.

Project: `elevatorquotationapp`  
Intended master email: `mahajanrahul45@yahoo.com`

Implementation checked on 8 October 2026: 23 Flutter tests and 11 Firestore
security tests pass; Android and Windows debug builds compile. The Firebase CLI
is authorized as `mahajanrahul45@yahoo.com` for this workspace. Firestore rules
were deployed on 8 October 2026 and the accounts index is READY. The existing
default database is in Mumbai (`asia-south1`). Authentication is initialized,
Email/Password is enabled, and the master Auth account and access profile are
provisioned. Use Forgot password to choose the master app password privately.
No changes were deployed to `biztaxora`.

Live configuration checks on 8 October 2026 confirmed that Android, web and
Windows settings match Firebase's registered apps. Their API keys belong to
project number `812581723084`. Deliberately invalid login requests return
`INVALID_LOGIN_CREDENTIALS`, not `CONFIGURATION_NOT_FOUND`. The earlier API
failure was observed before Authentication initialization; local configuration
did not need replacing. Run `node tools/check_firebase.cjs` for read-only checks.
Google is enabled in the console, but the app currently offers email/password
sign-in only. Browser workspace storage and synced images now have portable
paths. Some file/image actions elsewhere in the app still use native APIs.

## Deployment

1. Authorize the Google account that owns this Firebase project for the CLI:
   `firebase login:add mahajanrahul45@yahoo.com`
   Then select it for this app directory:
   `firebase login:use mahajanrahul45@yahoo.com`
   Signing into Firebase Console in the browser does not authorize the CLI.
2. Verify the project appears in `firebase projects:list`.
3. Create the default Cloud Firestore database in Firebase Console if it does
   not exist. Choose its region deliberately; the database location cannot be
   changed after creation. Use production mode.
4. Enable Authentication → Email/Password. The setup command below also
   enables this provider if Authentication has already been initialized.
5. Deploy the access rules and index:
   `firebase deploy --only firestore --project elevatorquotationapp`
6. Provision the master profile with the signed-in Firebase CLI credentials:
   `node tools/setup_firebase.cjs elevatorquotationapp mahajanrahul45@yahoo.com`
   The script locates a standard global Windows Firebase CLI installation. If
   installed elsewhere, set `FIREBASE_TOOLS_ROOT` to the directory containing
   its `firebase-tools` package. It never writes tokens or passwords to files.
7. Use **Forgot password** in the app to privately set the master's password.
   Existing Auth accounts keep their current passwords.

Master roles are provisioned by project administrators, never by the app.
No public sign-up can become a master. The existing Google Firebase owner
account and the app's master email can be different accounts.

## Use

Sign in as master and open **Users & permissions**. Invite each user's email
and select their allowed functions. Users select **Activate invited user
account**, choose a password, verify their email, and sign in. An uninvited or
unverified account cannot provision an access profile or read business data.

The master can change permissions, disable users, and select **Open user data**
to inspect or edit a user's workspace. **Return to master workspace** switches
back. Users can never switch workspaces, edit roles or permissions, or read the
master's or another user's records. Permissions apply to the database as well
as the navigation. Quotations/service/maintenance forms use the user's own
customers and products; grant those modules if the user needs those lists.
Service reports now also have **Add building**, available with service access
alone. It saves building name and location in that account's `service_buildings`
list. User service dropdowns show their own service buildings, not master or
other user customers. Editing an older report retains its existing building.
The master sees managed users' service buildings in the service dropdown and
**Customers -> View Customers**. Names are matched ignoring case and repeated
spaces; existing master customers take precedence in the display. This union
does not copy user buildings into the master customer records. User building
entries are shown read-only in the customer list; select **Open user data** to
work in that user's service workspace. Reopen the list to load remote changes.

Service report body settings now save online under `service_body_template`.
The five default inspection points are active; extra built-in or custom points
can be enabled using the checklist icon in a new Service Report or Service Page
Body in Saved Service Reports. Each active point gets an OK checkbox and optional
remarks. Work done, lift status and next service month are stored with the report,
along with a snapshot of its checklist and heading. Later template changes do
not alter saved reports. Existing reports without those fields remain readable
and show no recorded checklist rather than invented results. Body settings are
per workspace; the master can open a user's workspace to configure that user.
Preview, print, share and Download PDF use the same professional PDF builder.

Cloud payloads use the pure-Dart archive gzip codec, rather than `dart:io.gzip`.
This fixes browser `Unsupported operation: _newZLibDeflateFilter` during Save
body settings, while retaining the existing gzip/base64 format. Browser codec
tests also cover reading older payloads. The checklist-settings shortcut is
in the Service Report toolbar; returning from Saved Service Reports refreshes
the active checklist on an open new report. Native file/image features still
require Android or Windows; this compression fix is not a complete web migration.

On the original device, sign in as master and select **Import old device data**.
This imports local collections/settings only when an online key has never
been written, including preserving keys previously deleted online. Local
source records remain intact. Old device passwords are excluded and removed.
Logos and image/signature file attachments are uploaded with their records
and restored into each device's account-specific application cache. Missing
source images require reselection before migration; oversized payloads fail
visibly. User accounts never automatically inherit the master's old data.

All records are read from the server when a page opens. Use **Refresh online
data** on the dashboard to retrieve remote changes. Permission and account
status changes are watched live and reset the open navigation. An internet
connection is required; offline writes are deliberately disabled. Conflicting
updates ask the user to reopen the page rather than silently overwrite data.

## Verification

```
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build windows --debug
cd firebase_tests
npm ci
cd ..
firebase emulators:exec --only firestore --project demo-quotation-access "npm --prefix firebase_tests test"
```

The current Firebase CLI emulator requires Java 21 or newer. Security tests
cover anonymous access, master/user separation, other users, ungranted
functions, disabled accounts, permission revocation, role escalation,
invitation ownership, verified email enrollment, payload writes and revisions.

## Implementation limits

The existing record formats are preserved through a Firestore storage adapter.
Each collection/setting is compressed and split into 350 KB chunks, with an
atomic manifest and revision check. A single payload is limited to 100 chunks
and each transaction must remain within Firestore's transaction size limits.
Large catalogs should eventually use one document per business record. Reads
are grouped within simultaneous page loads but load all granted account data;
this is suitable for the current small-workspace app and has Firestore read
costs. Data pages refresh on opening, not continuously while editing.

Android builds currently use the repository's existing debug release signing
configuration; configure an appropriate release keystore before distribution.
Firebase's native Flutter Windows plugins are supported for development and
are not recommended by Firebase for production Windows use. Validate on your
target PCs; a production desktop rollout should use a supported web client or
a backend/API for desktop access. This change does not convert the existing
`dart:io` app to a web app.

References: [Firebase Flutter setup](https://firebase.google.com/docs/flutter/setup),
[Firebase Authentication](https://firebase.google.com/docs/auth/flutter/password-auth),
[Authentication and security rules](https://firebase.google.com/docs/rules/rules-and-auth).

## Service report dates, dictation and languages

New reports initialize both the report date and lift service date to the
current device date. Service Month defaults to the current month and Next
Service Month to the following month, including December-to-January year
rollover. Calendar buttons remain editable. Editing a saved report retains
its original dates and months.

The top English/Hindi selector translates standard form wording, built-in
inspection points, statuses, month names and default work remarks. Names,
locations, custom inspection points and custom remarks remain as entered.
Reports store `languageCode` alongside their existing fields; old reports
default to English. Print, download and share use the saved language.

Every checklist remarks field, report work/remarks field and body settings
default remarks field has a microphone. Tap to start, speak, then tap again
to stop. Dictation inserts at the caret or replaces selected text. Partial
recognition updates replace the same utterance instead of duplicating it.
Only one field listens at a time; leaving the field/page or switching
languages cancels listening. Typing remains available after stopping.

Microphone permission and a device speech recognizer with the selected
language are required. Android may need Google speech services and an
internet connection. Web recognition depends on browser support and
microphone permission (use HTTPS or localhost). Windows recognition in
the plugin is beta; if unavailable, focus the remarks box and use Win+H.
See [speech_to_text platform documentation](https://pub.dev/packages/speech_to_text/versions/7.4.0).

The licensed Noto Sans Devanagari font is bundled for offline Hindi display.
Hindi PDF cells use Flutter's text shaping rendered at 288 dpi, preserving
conjuncts/vowel positions and the paginated table layout. These shaped text
cells are images in the PDF. English PDFs retain their original text renderer.

Verification: 30 Flutter tests cover default/edit dates, language switching
at 320/1200px, preserved custom text, simulated recognition language and
partial results, current-field routing and disposal, report compatibility,
and standard/multiple-page Hindi PDFs. A microphone/hardware check is
still required on the target phone/PC. No production Firestore records
were changed by this update.

## Saved service reports

The saved reports screen uses responsive report cards with service dates,
next month, technician, lift status and PDF language. Search covers building,
location, report number, month and service person. Status filtering and
sorting are display-only. The page includes online refresh, new report,
preview/print, edit and direct PDF sharing, plus loading/error/empty states.
Sharing uses generated PDF bytes and a readable filename across platforms.

Delete requires confirmation, a fresh online read, the same workspace and
an unchanged selected report. It preserves all other records, including
records hidden by filters. Failed deletes do not remove the card locally.
The 13 relevant Flutter tests passed, including phone/desktop layout,
search/status filtering, filtered deletion and existing service workflows.
No live Firestore records were changed while implementing this screen.

## Install alongside the old local Android app

The online Android app is registered separately in the existing Firebase
project `elevatorquotationapp`:

- Android application ID: `com.mahajan.elevatorquotation.cloud`
- Launcher name: **Elevator Quotation Cloud**
- Firebase Android app ID: `1:812581723084:android:dd92519faa64a235ff5b69`

The previous Android identity `com.example.elevator_quotation_app` is retained
in Firebase. The Kotlin namespace remains unchanged; the installer identity
is the new application ID. Firebase options, Google Services configuration
and FlutterFire metadata now agree on the new cloud app registration.
Windows/web identities and all saved Firebase records remain unchanged.

Install `output/android/Elevator_Quotation_Cloud.apk` alongside the existing
local app. Android keeps each package's data in separate storage; this APK
does not update or uninstall the old app. Sign into the Cloud app with the
same Firebase login to access online data. Future builds with this cloud
package ID update the cloud app only. Keep the signing key consistent.

Local records remain in the old app. A different Android package cannot
read that app's private local storage directly. If old records need to move
into Firebase, use an explicit export/import workflow. Do not uninstall the
old local app as part of installing this Cloud app.

## Cloud logo palette (version 1.0.1+2)

The existing gear logo is recoloured in navy and teal to match the app UI
and distinguish Cloud from the installed legacy app. Its source is
`assets/icon/app_icon.png`; the original is backed up in
`output/app_icon_original.png`. The built-in image-edit tool's exact prompt
is saved in `output/branding/logo_edit_prompt.txt`.

Launcher icons are regenerated for Android, iOS, web, Windows and macOS
using the `flutter_launcher_icons` configuration in `pubspec.yaml`.
Run `flutter pub run flutter_launcher_icons` after future source-icon edits.
The Android package ID remains `com.mahajan.elevatorquotation.cloud`.

## Shared customer and building directory

Quotation, maintenance quotation, and service report selectors now combine the
current workspace's `customers` and `service_buildings` lists. The master also
sees both lists from invited accounts, with account attribution. Source lists
are retained; selectors collapse duplicate names while the master customer
management lists retain source records.

In Customers, use **Approve user access** on a master-owned customer/building.
Select enabled invited users and save. Approval publishes the current customer
snapshot to only those users; save approval again after changing its details.
Clear a selection to revoke access. Deleting a master customer also removes
its published share. Sharing does not grant report or master-data edit access.
Existing reports remain intact when directory access is revoked.

Deploy the updated `firestore.rules` alongside the app before using this feature:

```powershell
firebase deploy --only firestore:rules --project elevatorquotationapp
```

Cross-account directory reads and approval changes require an online connection.
Source records created offline continue to use the existing workspace sync; they
become visible to the master after syncing. Approved shares are read from the
server so stale offline approvals are not reused after access is revoked.
