# quotation_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web app

For the browser, run `flutter run -d chrome`. For deployment, run
`flutter build web` and serve the entire `build/web` directory, including
`canvaskit/`. Open the app through an HTTP/HTTPS server rather than opening
`index.html` directly. Firebase sign-in still requires internet access.
The browser loader uses bundled renderer files and offers Try again if startup
fails or takes longer than 30 seconds.

## Offline workspace

Sign in with internet once and allow the workspace to download. Keep that account signed in. Customers, products, quotations, maintenance records, service reports and settings can then be read and saved offline. Attached images and signatures are included in the local cache and upload payload.

Changes are saved in an account-scoped persistent outbox before the save completes. While the app is running, synchronization retries every 20 seconds and also runs after saves and session startup. Reopening the app resumes queued uploads. After synchronization, reopen a list/form to load its refreshed data. The status banner shows offline, pending and failed synchronization; tap it to retry.

Conflicting edits on another device are preserved locally. Tap the conflict banner and choose Keep online (discard conflicting local changes) or Keep this device (replace the conflicting online values). Conflicts apply to an entire stored list/settings value, not individual records.

First-time login, invitations, user administration and online sharing services require internet. Offline access uses the last verified account permissions; account disablement and permission changes take effect once received online, and server rules validate all uploads. Signing out requires online sign-in to enter the account again. Clearing app storage removes cached data and unsynchronized changes.

Device validation before release: sign in online; switch on airplane mode; create/edit/delete a record and attach a signature; close and reopen the app; verify the offline changes; reconnect and confirm the same records on a second device. Also edit the same list on both devices and verify both conflict choices. Real-device reconnection and Firebase transaction behavior are not covered by the local storage unit tests.


## Workspace backup and restore

In the master workspace, select **Backup Data** on the dashboard or in Settings.
Choose a destination (the browser starts a download). Keep the resulting JSON file
in a private location: it contains business records and settings and is not encrypted.
The backup covers the current account's CloudPreferences workspace, including
products, customers, quotations, maintenance records, service reports, print/email
settings and embedded images/signatures. It excludes login credentials, reset PINs,
device caches and account/user permissions stored separately in Firebase.
It captures the data available on this device; allow cloud sync to finish first
if you need recent changes from other devices.

To restore, sign into the intended master workspace, select **Restore Data**, choose
the JSON file and review the confirmation. Matching data sections are replaced;
sections absent from the file remain unchanged. Make a current backup first if you
need the previous versions. Version and checksum checks detect damaged new backups.
Original legacy backups are supported but only contain their original limited sections.
All imported sections are prepared before a single durable local save; cloud upload
then follows the normal offline sync and conflict resolution workflow. A successful
local restore does not mean every section has already uploaded to Firebase.
