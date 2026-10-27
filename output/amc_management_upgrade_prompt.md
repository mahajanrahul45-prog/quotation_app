# Implementation Prompt: Professional Elevator AMC Management Upgrade

## 1. Objective and working approach

Upgrade the existing Flutter Elevator Quotation App into a professional Annual Maintenance Contract (AMC) management system. Extend the existing implementation; do not rebuild the app.

Inspect the repository instructions, models, account permissions, customer/building directory, storage and synchronization, maintenance quotation form, saved quotations, status pages, dashboard counters, expiry reminders, PDF generation, and sharing actions before making changes.

Reuse working code and the existing storage architecture. The app already has renewal functionality: inspect it and extend it instead of adding a second renewal system.

Preserve existing records, IDs, dates, amounts, customer permissions, and working features. Do not reset storage, silently merge records, or overwrite history. Do not discard unrelated local changes. Implement the upgrade directly in the existing project and verify the result.

## 2. Consistent terminology and record identity

Use **Customer / Building Name** wherever the app labels the customer/building name. Keep a representative's personal name and signature labels separate. Preserve English/Hindi support.

Maintain distinct concepts:

- **Customer/building:** A stable directory record used across quotations, maintenance quotations, and service reports.
- **Elevator:** A stable lift record belonging to a customer/building, with a readable lift number.
- **Quotation:** A proposal with its own immutable ID, readable quotation number, saved details, and acceptance state.
- **AMC contract:** A confirmed maintenance agreement covering specified lifts and dates.
- **Renewal:** A new quotation explicitly linked to a previous quotation/contract and the relevant lifts.

Use stable, account-scoped IDs for relationships. Customer names are display/search values, not identifiers. Matching names alone must never merge customers, renew contracts, or remove records from the Expired view.

Support multiple elevators under one customer, with independent AMC periods. Where one quotation covers several lifts on identical terms, retain its grouping and link each covered lift explicitly.

Preserve existing IDs. Introduce readable quotation numbers such as `AMC-2026-0001` using a concurrency-safe strategy within the account's numbering scope. Never renumber historical quotations or reuse numbers. Handle offline-created quotations without generating duplicate final numbers.

## 3. Quotation acceptance and AMC lifecycle

Keep customer category, quotation acceptance, calculated contract status, and renewal activity separate.

**This upgrade intentionally changes the current immediate-renewal behavior:** saving a new renewal quotation must not automatically activate it or replace the existing AMC.

New quotations start as **Pending**. Provide explicit **Confirm AMC** and, where appropriate, Cancel/Reject actions. Prevent repeated confirmation from creating duplicate contracts.

Calculate confirmed contract status from the current local calendar date, with inclusive start and end dates:

| Status | Rule |
| --- | --- |
| Upcoming | Today is before the confirmed start date. |
| Expired | Today is after the confirmed end date. |
| Expiring Soon | Today is within the contract period and 0–30 calendar days remain. |
| Active | Today is within the contract period and more than 30 calendar days remain. |

Expiring Soon is a highlighted subset of an in-force AMC; use exclusive status filters so a contract is not counted twice in status totals.

**Pending Quotation** is an acceptance state, not an active contract. **No Contract** is a customer/lift-level condition meaning no confirmed contract exists; do not create fictitious quotation records to represent it.

**Previous Contract** is a historical designation. Preserve the historical period and its end/expiry information without including it in current-contract totals once its replacement takes effect.

Refresh calculated statuses when screens open, the app resumes, or the local calendar date changes. Use one shared calculation for saved quotations, status pages, dashboard counts, and reminders.

## 4. Renewal workflow

Keep **Renew AMC** in the existing quotation menu. Open a prefilled form with:

- Customer / Building Name and existing customer ID.
- Previous quotation number and contract dates, read-only.
- Selected existing lift IDs/numbers and lift quantity.
- New start and end dates.
- Calculated duration.
- Amount per lift and calculated total.
- Optional remarks.

Retain the selected customer's identity during renewal. Allow lift selection, dates, quantities, and pricing to change with validation. Derive quantity from selected lift IDs when individual lifts are available; do not allow the quantity and selection to disagree.

Suggest the next start date as the later of today or the day after the previous contract ends. Allow a different valid date. Suggest an end date using calendar-month arithmetic and show the inclusive coverage period clearly.

Provide these actions:

1. **Save Renewal Quotation:** Save a new Pending quotation with a new ID/number and an explicit link to its predecessor. Keep the previous AMC unchanged.
2. **Save & Confirm AMC:** Validate, save the new quotation, and confirm its contract in one consistent operation.
3. **Cancel:** Leave all saved records unchanged.

Also provide **Confirm AMC** for an already saved Pending quotation.

Before confirmation, validate dates, amounts, lift ownership, and overlapping confirmed periods for every selected lift. Block accidental duplicate renewal/confirmation, including concurrent submissions.

A future-dated confirmed renewal is Upcoming. The previous contract remains current until its period ends or an explicitly approved replacement becomes effective. Do not archive it merely because a future renewal was saved or confirmed.

For partial renewal, update current coverage per lift. Unrenewed lifts must retain their own status and may remain Expired. Preserve quantities and lift selections on every historical quotation.

## 5. Existing-customer detection

When an existing customer is selected in a new quotation, look up relevant maintenance records by stable IDs. If records exist, offer:

- **Renew Existing AMC**
- **Create Separate Quotation**
- **Cancel**

If several contracts or lift groups exist, require selection of the correct predecessor and lifts. Do not silently choose the latest quotation for the entire customer.

Creating a separate quotation must reuse the customer record without creating a renewal link or replacing an existing AMC.

## 6. Renewed This Month

Preserve the previously requested monthly renewal view.

Record a renewal's completion timestamp when the AMC renewal is **confirmed**, not when its draft is saved. Editing a confirmed quotation must not change this timestamp.

Show confirmed renewal events completed during the current local calendar month in **Renewed This Month**. This is an activity view, separate from contract status: a renewal may also appear in Upcoming, Active, or Expiring Soon as its dates require.

At the next calendar month, remove the event from this view automatically. Do not delete the quotation, contract, timestamp, or history. Its date-based status remains available. Distinguish the year as well as the month.

## 7. Calculations and validation

For a flat per-lift amount covering the full selected period:

`Base amount = Number of selected lifts × Amount per lift`

Example: 3 lifts × ₹18,000.00 = ₹54,000.00. Do not multiply by duration again. Preserve existing GST, discount, rounding, and charge calculations where supported, with a clear final total.

Use appropriate monetary precision, preferably integer paise or the project's existing decimal mechanism. Avoid a destructive conversion of historical amounts.

Calculate duration from inclusive dates using calendar months and remaining days. Do not assume every month contains 30 days. Define and test month-end and leap-year behavior. If the user enters a requested month count to suggest dates, recompute the displayed duration after manual date changes.

Validate finite amounts, positive lift quantity, valid lift selection, start ≤ end, renewal linkage, and account permissions. Show clear field-level messages and prevent repeated submission while saving.

Display **Ends today**, **Expiring in N days**, **Expired N days ago**, or **Starts in N days** as appropriate. Calculate calendar-day differences without time-of-day or daylight-saving errors.

## 8. Customer categories

Provide **All | Regular | Quote | New** as a compact category filter.

- **Regular:** An established maintenance customer.
- **Quote:** A prospect classified for quotation follow-up.
- **New:** A customer beginning maintenance services for the first time.

Persist category changes separately from quotation acceptance and AMC status. Do not automatically change Regular to Quote because a renewal is Pending. Do not change New to Regular without user confirmation or an explicitly configured rule.

Respect ownership and existing sharing permissions when changing categories. A user's category edit must not silently alter an inaccessible master record or another user's customer.

## 9. Saved quotations and history UI

Use Material 3 and the app's existing theme, including dark mode. Use responsive mobile cards and a readable desktop/tablet list or table where suitable.

Each record should clearly show:

- Customer / Building Name and area.
- Customer category.
- Quotation number and acceptance state.
- Covered lift numbers and quantity.
- Maintenance period and calculated duration.
- Amount per lift and total amount.
- Confirmed contract status and remaining/overdue days, where applicable.
- Added-by attribution and renewal information where relevant.

Provide combined category, acceptance, and contract-status filters. Search by customer/building, lift number, and quotation number. Sort by newest/oldest quotation, name A–Z/Z–A, nearest expiry, and total amount high/low. Apply filters together and keep sorting deterministic.

Make it clear whether a view lists quotation records, current contracts, or customers/lifts without contracts. Do not imply that a Pending proposal is the customer's current confirmed AMC.

Provide **View History**, with customer-wide and lift/contract-specific scopes. Show current coverage, future confirmed coverage, pending proposals, and previous periods in clearly separated sections. Preserve all predecessor links and display original dates, quantities, prices, acceptance events, and audit information.

Keep the existing three-dot menu and working actions, including View/Preview, Edit, Renew, PDF export, Mail, WhatsApp, and existing Delete behavior. Add only missing History, Category, and Confirmation actions. Avoid duplicate entries. Preserve appropriate safeguards for deleting confirmed or historical records.

Maintain consistent spacing, readable status chips, clear empty/loading/error states, Retry actions, and a visible Saved Quotations shortcut. Use `DD/MM/YYYY` and Indian currency formatting such as `₹30,000.00`. Avoid raw exception text in the UI.

## 10. Summary cards and counting rules

Provide clearly labeled, clickable summaries:

- Pending quotation customers: unique customers with at least one Pending proposal.
- Regular customers: unique customers classified Regular.
- New customers: unique customers classified New.
- Active, Upcoming, Expiring Soon, and Expired AMCs: distinct contract/lift coverage records under the defined grouping rules.
- Renewed This Month: confirmed renewal events in the current month.

Specify the unit on each card; customer counts and contract counts are different. Multiple proposals must not inflate customer totals. Do not double-count a grouped contract merely because it covers multiple lifts. If showing lift counts, label them explicitly.

Summary cards should use all records accessible within the current account scope and apply the corresponding list filter when clicked. Clearly distinguish summary totals from the currently filtered result count.

## 11. Historical integrity, PDFs, and sharing

**Edit** updates the selected quotation while retaining its ID/number. **Renew** creates a new linked quotation and never overwrites its predecessor.

Preserve an audit revision before changing confirmed or historical quotation values, recording the actor, time, and changed fields. Restrict sensitive edits to authorized users.

Keep saved customer/building details, lift selections, prices, dates, tax/discount values, and relevant PDF configuration as historical snapshots. Updating the customer directory or current pricing must not rewrite historical quotations.

Retain original PDF files where available. If no original exists, regenerate from the saved snapshot and distinguish it from an archived original. Do not claim to reproduce an original PDF exactly when its template/assets were not saved.

Preview, export, email, and WhatsApp must use the selected quotation/revision's correct data and PDF. Preserve existing sharing behavior; development and testing must not send unsolicited messages.

## 12. Storage, migration, and account access

Reuse the existing account-scoped storage, durable offline synchronization, and conflict handling. Do not introduce an independent conflicting database or bypass security rules.

Extend the model as needed for stable customer/building/lift IDs, quotation identity and number, predecessor links, covered lifts, category, acceptance/confirmation state, contract dates, monetary values, remarks, creator/updater identity, confirmation/renewal timestamps, snapshots, and audit revisions. Calculate time-dependent status dynamically.

Migrations must be backward-compatible, repeatable, and non-destructive:

- Preserve existing IDs and unknown fields where possible.
- Keep existing records accessible while identifiers and relationships are introduced.
- Preserve established legacy behavior through an explicit compatibility policy; do not silently mark all old contracts Pending or Confirmed.
- Do not invent historical confirmation dates, renewal timestamps, or lift identities.
- Flag ambiguous customer/lift matches for review rather than automatically merging them.
- Preserve renewal/history fields through backup, restore, export, and import.
- Import must not silently replace the complete existing database.

Retain the common customer/building directory and invited-user approvals already implemented. The master may view managed users' records with **Added by** attribution. Invited users see their own records and explicitly approved master customers, subject to existing permissions. Do not expose another user's private quotations, contracts, history, or PDFs through a shared customer ID.

Enforce authorization at the storage/security-rule layer, not only in the UI. Record actor IDs for confirmation, renewal, and category changes. Clearly show Pending sync, Failed, and Conflict states; a local save must not be presented as server-confirmed when it is not.

## 13. Required verification

Add focused tests and run appropriate checks for:

1. Existing records surviving migration and restart without data loss.
2. Customer/lift IDs reused correctly; unrelated matching names remaining separate.
3. Multiple lifts and partial renewals with independent dates/statuses.
4. Separate quotation creation without an unintended renewal link.
5. Pending renewal leaving current coverage unchanged.
6. Confirmation creating one valid AMC and preserving its predecessor.
7. Future renewal remaining Upcoming while current coverage continues.
8. Duplicate submission and overlapping coverage prevention, including concurrent clients.
9. Inclusive expiry-day behavior and the 30-day boundary.
10. Monthly Renewed rollover, including December/January and different years.
11. Calendar-month, month-end, leap-year, duration, and monetary calculations.
12. Category, search, acceptance/status filters, sorting, and summary counts working together.
13. Audit revisions and historical PDFs retaining original values.
14. Existing menu, preview, export, and sharing paths remaining functional.
15. Offline persistence, synchronization conflicts, and migration idempotency.
16. Master/invited-user permissions, sharing revocation, and cross-account isolation.
17. Responsive layouts at narrow mobile and desktop widths in light/dark mode, including bilingual labels.

Resolve dependencies only if needed. Run `flutter analyze` and relevant `flutter test` suites, plus security-rule tests when rules change. Separate pre-existing failures from regressions introduced by this upgrade. Report anything that could not be verified rather than claiming it passed.

## 14. Delivery

Finish with a concise report covering:

- Modified and new files.
- Renewal, confirmation, effective-date, and monthly-view behavior.
- History, PDF snapshots, and duplicate-customer protection.
- Migration and legacy-data handling.
- Preserved menu/sharing actions and account permissions.
- Tests run, results, remaining limitations, and any deployment steps.

The final system must manage one stable customer/building directory, independent lift coverage, explicit quotation acceptance, traceable renewals, and permanent history through a consistent professional interface.
