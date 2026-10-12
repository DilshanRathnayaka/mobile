Follow-up review after the Antigravity implementation

Reviewed 11 October 2026. Scope: the current Flutter mobile app and the four Supabase migrations. The unused sibling server remains out of scope. This is a review, not an implementation: application code and live Supabase data were not changed.

**Assessment**

Several important improvements are present: real Supabase TOTP enrollment/verification, a Keychain/Keystore session adapter, biometric failures returning false, Android/iOS biometric configuration, RPC-based ledger mutations with advisory locks, retained realized P&L, canonical coin mapping, and USD normalization of salary input. However, the security and financial-integrity boundaries are still incomplete. Complete the high-priority findings below before treating the app as ready for real financial records.

The findings below distinguish locally reproduced defects from source-level findings. Local database tests used isolated PostgreSQL 18 on localhost, a minimal emulation of Supabase auth roles/JWT functions, and the repository's actual migrations. They did not test the deployed Supabase project's current policies, grants, Auth service, or PostgREST settings. The temporary database server was stopped after testing.

**Verification results**

| Check | Result |
| --- | --- |
| `flutter analyze --no-pub` | No analyzer errors; two unused-import warnings at the time of the run (`dashboard_screen.dart`, `main_screen.dart`). |
| `flutter test --no-pub` | Existing 16 tests passed. |
| Two additional focused regression checks | Both failed: account B loaded account A's local cashflow; CSV contained 14 data fields under 13 headers. |
| Fresh database, migrations 1–4 | Applied successfully. |
| Repository `supabase/tests/database_test.sql` | Passed against the isolated fresh database, despite the authorization defects below. |
| Explicit role/JWT security probes | Confirmed AAL1 RPC writes, anonymous helper access, and direct-table oversells under the tested grants. |
| Fresh signup bootstrap probe | Inserting an Auth user did not create its required profile. |
| Original schema + existing BTC position + migrations 1–4 | Migration 4 failed with `duplicate key value violates unique constraint "unique_user_coin"`. |
| Legacy numeric-column inspection | `transactions.price_per_unit` and `holdings.average_buy_price` remained `numeric(20,4)`. |

Review-only reproduction files are in `.dart_tool/review/`: `regression_checks_test.dart`, `bootstrap.sql`, `security_probes.sql`, `legacy_bootstrap.sql`, and `legacy_fixture.sql`. These are not production migrations. The Flutter checks intentionally assert the desired safe behavior and currently fail. Run them explicitly with `flutter test --no-pub .dart_tool/review/regression_checks_test.dart`. The SQL security probe asserts that the defects can be reproduced; replace it with denial assertions when implementing permanent security tests. Never run these fixture/bootstrap files against production.

**1. HIGH — Financial RPCs bypass the MFA policy**

Evidence: `supabase/migrations/20261011000003_atomic_financial_rpcs.sql:122`, `:214`, `:295`, `:356`, `:458`; MFA predicate at `20261011000002_security_rls_mfa.sql:10`.

All five write RPCs run as `SECURITY DEFINER`. They obtain a user ID but never enforce MFA inside the function. RLS on the underlying tables cannot supply this missing check when the function owner bypasses RLS. In the local test, an authenticated user with a verified TOTP factor and an `aal1` JWT had `is_mfa_compliant() = false`, yet `create_trade` successfully created a trade and holding.

Fix: every exposed financial RPC must require a non-null `auth.uid()`, the selected MFA policy, and ownership before taking any action or returning an idempotent result. Remove the client-facing fallback to a supplied `p_user_id`; keep administrative/test execution separate. Apply authorization to reads as well: profile reads currently expose `monthly_salary` at AAL1. The predicate also deliberately permits users with no verified factor, which does not implement the handoff's recommended mandatory-MFA policy. Keep only minimal bootstrap/enrollment data available before MFA.

Acceptance: exercise each RPC as anon, AAL1 with an enrolled factor, AAL1 without a factor under the chosen policy, AAL2 owner, and AAL2 different owner. Denied attempts must leave the ledger, holdings, audit, and idempotency tables unchanged.

Supabase explicitly requires MFA enforcement at the API/database boundary and warns that privileged definer functions can bypass RLS: [MFA guidance](https://supabase.com/docs/guides/auth/auth-mfa), [database function security](https://supabase.com/docs/guides/database/functions).

**2. HIGH — The internal holdings helper is callable anonymously**

Evidence: `supabase/migrations/20261011000003_atomic_financial_rpcs.sql:27` and the permissions loop at `:493`.

`internal_recalculate_holding` is a public-schema definer function accepting an arbitrary user ID. The final revoke/grant loop includes the five mutation RPCs but omits this helper. PostgreSQL's default PUBLIC execute privilege therefore remains unless deployment settings revoke it separately. A local anon-role call inserted an arbitrary zero-balance holding into another user's account. Existing holdings can also be recalculated without the outer RPC's per-user lock. This test did not demonstrate arbitrary positive balances or reading another user's entire ledger.

Fix: move the helper to a non-exposed private schema, revoke execute from PUBLIC, anon, and authenticated, and allow only the trusted mutation functions to call it. Ensure every entry point that rebuilds holdings follows the same locking rules. Audit all public function signatures and effective grants, not just function names.

Acceptance: direct anon/authenticated execution of the helper must fail; the authorized outer RPC must still work. Default function execution and explicit grants are described in [Supabase's function-security documentation](https://supabase.com/docs/guides/database/functions).

**3. HIGH — RPC failures fall back to writes that bypass ledger validation**

Evidence: `lib/data/services/supabase_service.dart:313`, `:374`, `:415`, `:508`, `:579`; `transactions_modify_own` and `salary_allocations_modify_own` at `20261011000002_security_rls_mfa.sql:59` and `:83`.

Each write catches any RPC error and attempts direct table operations. This includes inventory violations, authorization failures, and an uncertain network response after a commit. The migration leaves direct financial-table DML available under its policies. In the local test, a user owning 1 BTC directly inserted a 2 BTC sale successfully. With fresh migrations there is no automatic holdings trigger for this path, so the ledger and holdings also diverge. Salary fallback is multiple independent requests and can partially commit.

Fix: remove all direct-write fallbacks. Revoke client INSERT/UPDATE/DELETE on authoritative financial and idempotency tables; permit mutations only through constrained RPCs. Surface typed validation, permission, connectivity, and schema-version failures. Add database constraints for valid types, positive/finite amounts and prices, nonnegative/finite fees, and valid FX values as defense in depth.

Acceptance: an oversell from the app produces an error and no database change. Direct REST/table writes are denied. Simulated lost responses cannot create an extra record through a fallback path.

**4. HIGH — Account switching exposes the previous account's cashflow**

Evidence: `lib/providers/cashflow_provider.dart:14`, `:24`; provider invalidation at `lib/providers/session_provider.dart:20`.

Cashflow is stored in plaintext SharedPreferences under the global key `user_cashflow_records`. Logging out invalidates the provider but leaves that key intact. The next account's provider reloads the same records without checking an owner. A focused test seeded Alice's cashflow and initialized a notifier for an empty Bob account; Bob received Alice's record.

Fix: make Supabase cashflow rows owner-scoped with RLS. If retaining an offline cache, namespace it by project/account, protect sensitive contents, clear in-memory state on transitions, and discard responses from a previous session generation. Do not automatically attribute the existing unowned local records to whoever logs in next; provide an explicit migration/reconciliation step for the known original owner.

Acceptance: A → logout → B, restart, delayed request completion, and offline startup must never expose A's records to B.

**5. HIGH — Login navigation removes the app-lock guard**

Evidence: `lib/screens/auth/auth_screen.dart:32`, `lib/main.dart:95`, `lib/providers/security_provider.dart:39`, `lib/data/services/supabase_service.dart:86`.

Successful login calls `Navigator.pushReplacement` with `MainScreen`, replacing the route that contained `AuthGate`. The lifecycle observer can then set `isAppLocked = true`, but the active screen has no gate to render the unlock page. On restored sessions, a pushed detail/settings route can likewise remain above the guarded home route. Cold startup also starts unlocked before asynchronous security preferences finish loading.

MFA has a related routing gap: the home gate checks only `currentUser`, not assurance level; a restored AAL1 session is sent to the main screen. `getMfaStatus()` converts errors into 'not enrolled', and the login flow treats that as permission to proceed. These source-level paths were not tested on physical devices.

Fix: keep one reactive auth/MFA/lock state machine above the complete Navigator, with explicit loading/error states. Change state after login instead of bypassing the guard with a new main route. Block private screens until session, MFA, and lock initialization complete; obscure app-switcher content. Scope settings appropriately and require verification before disabling the lock. Fix nullable `lastBackgroundedTime` clearing: the current `copyWith` retains the old value when passed null.

Acceptance: cold launch, login → background for over 30 seconds → resume, any open detail route, restored AAL1 session, sign-out, and MFA network errors must all show the correct gate. Verify on shipped Android/iOS devices.

**6. HIGH — The upgrade migration fails with existing holdings**

Evidence: `supabase/migrations/20261011000004_currency_and_asset_reconciliation.sql:45`, `:50`; original `../supabase_schema.sql:187`; baseline migration `20261011000001_baseline_tables.sql:53` and `:89`.

Reproduction: load the original schema, create one legacy BTC purchase with `coin_id = 'btc'`, apply migrations 1–3, then apply migration 4. Updating the transaction to `bitcoin` invokes the still-installed legacy recalculation trigger and creates a new `bitcoin` holding. Renaming the existing `btc` holding then fails on `(user_id, coin_id)` uniqueness. Mixed alias/canonical holdings also need reconciliation independently of that trigger.

The baseline's `CREATE TABLE IF NOT EXISTS` statements do not change existing numeric columns. Inspection after migrations 1–3 confirmed price and average-price columns still use four decimal places. Old triggers and old/new table definitions therefore differ between upgraded and fresh installations.

Fix: prepare an additive upgrade with a documented backup/restore path; retire the old trigger in a deliberate transaction, alter existing numeric types, reconcile ambiguous asset IDs, and rebuild one holding per owner/canonical asset from the ledger. Preserve realized P&L and report conflicting legacy data. Add unique linkage for salary deposits after reconciling existing duplicates. Do not simply rename colliding derived rows or fabricate missing historical currency information.

Acceptance: run the complete migration chain on both a fresh database and representative copies of the original schema, including aliases plus canonical IDs, tiny prices, closed positions, and duplicate/unlinked salary deposits. Compare ledger totals before and after.

**7. HIGH — Client retries are not idempotent end to end**

Evidence: `lib/data/services/supabase_service.dart:286`, `:346`, `:405`, `:485`, `:569`; RPC idempotency lookup at `20261011000003_atomic_financial_rpcs.sql:131`.

The database remembers an operation UUID, but the client generates a fresh UUID for every service invocation. If the server commits and the response is lost, pressing Save again submits a different operation and can create a duplicate trade. The current catch-and-direct-write path makes the same uncertainty worse. The RPC lookup also does not validate the operation type or payload when a key is reused, and updates have no expected-version check.

Fix: create one operation ID per user action before sending, retain it with the immutable payload until the result is known, and reuse it for retries. Store/check operation type and a normalized payload hash. Add optimistic version checks to edits/deletes so two devices do not silently overwrite each other's changes.

Acceptance: commit-then-timeout → retry creates exactly one trade; reuse with a different payload is rejected; concurrent stale edits report a conflict.

**8. HIGH — Original-currency values are still incorrect or discarded**

Evidence: `lib/screens/salary_dca_screen.dart:320`, `lib/data/services/supabase_service.dart:494`, `lib/screens/add_transaction_screen.dart:188`, `20261011000003_atomic_financial_rpcs.sql:410` and `:422`.

Salary input is now divided by the display conversion rate before storage, which fixes the basic LKR-as-USD problem. However, the screen's `originalSalaryAmount` and `originalAllocatedAmount` are discarded by the service, and the schema has no matching columns. The linked deposit stores the USD allocation as `original_amount` while labeling its currency LKR.

For example, with the app's configured rate of 305 LKR per USD, an LKR 30,500 allocation stores USD 100 correctly as its base amount, but labels original amount 100 as LKR instead of 30,500. Trade entry also labels USD/USDT-price input with the selected display currency and stores coin quantity as the original monetary amount. Display-currency changes should not change the provenance of a transaction.

Fix: define quantities separately from original monetary amounts, original currency, base amounts, historical FX direction, timestamp, and source. Persist all of them and preserve them on edit. Use an explicit manual dated FX rate or a verified rate source; the current hardcoded rates have no timestamp. Treat USDT separately from USD or clearly model the chosen conversion assumption. Backfill only values supported by evidence and flag ambiguous legacy records.

Acceptance: LKR salary/trade save → reload → edit → export preserves original values and rate. Test currencies with rates above and below one and an explicit USDT conversion case.

**9. HIGH — Cashflow is not a durable, consistent financial ledger**

Evidence: `lib/providers/cashflow_provider.dart:73`, `:104`, `:117`, `:141`; `lib/screens/deposit_withdraw_screen.dart:529`.

Most deposits/withdrawals exist only in local preferences and disappear on reinstall or another device. A 'salary' cashflow creation upserts that month's salary allocation with salary equal to the deposited amount and 100% allocation, potentially overwriting a separately entered salary/allocation. Editing or deleting that local cashflow never updates the linked Supabase entry. Multiple local salary inflows can therefore coexist with only one overwritten monthly allocation. Persistence errors are swallowed, and the screen shows success without awaiting add/update completion.

Fix: choose one authoritative cashflow model in Supabase, with explicit income, investment transfer, and withdrawal semantics. Link salary allocation rather than creating a second independent record. Make create/edit/delete atomic where linked data is involved; await results and surface failed or pending sync. Derive the dashboard totals from the same authoritative source.

Acceptance: edit/delete propagates everywhere, two devices agree, repeated salary inflows do not overwrite gross salary, and a failed save never displays unconditional success. Transfer of money between the user's accounts must not be counted as new income or spending.

**10. MEDIUM — CSV export is malformed and limited to the latest 100 transactions**

Evidence: `lib/core/utils/export_service.dart:30`, `lib/screens/analytics_screen.dart:763`, `lib/data/services/supabase_service.dart:230`, `:265`.

The formatted date contains a comma, e.g. `Oct 11, 2026`, and is not CSV-quoted. The targeted parser test returned 14 data columns for 13 headers, shifting every later field. A full-history pagination helper was added, but export still passes the provider's default latest-100 list. Fee/trade totals using that list are also incomplete for older histories. A dismissed share sheet is reported as success. JSON generation is not wired to an export/restore flow and currently contains only transactions.

Fix: use a CSV encoder or apply escaping consistently to every field, including dates; retain formula-injection protection. Wire full-history retrieval with a stable ordering/snapshot strategy to export and full-period analytics. Distinguish share cancellation. Implement a documented backup/restore format with ownership validation, dry-run, deduplication, and all authoritative financial records before advertising restorable backup.

Acceptance: parse exported CSV back into the expected column types; test commas, quotes, newlines, formulas, and 501+ transactions. A backup round trip into an empty test account must reconcile totals.

**11. MEDIUM — Missing market prices still appear as valid current valuations**

Evidence: `lib/data/services/supabase_service.dart:168`, `:181`; `lib/data/models/holding_model.dart:1`.

When no quote exists, the portfolio service substitutes average purchase price and marks the temporary price map stale. That status is dropped when creating `HoldingModel`, which has no freshness/source/timestamp fields. The dashboard can therefore present an unavailable quote as break-even current value. Cached stale quotes lose their status the same way.

Fix: carry quote state, timestamp, and source through the model and UI. Show stale values explicitly; distinguish unavailable valuation from zero or purchase price, and disclose incomplete portfolio totals.

Acceptance: disconnect the quote provider and use an unsupported asset. The UI must not silently report a live break-even valuation.

**12. MEDIUM — The equity chart does not calculate equity**

Evidence: `lib/screens/analytics_screen.dart:305`, `:312`, `:340`.

The 'Equity Curve / Historical Capital Valuation Trajectory' starts at zero inside the selected range, adds buy totals, subtracts sale proceeds, and clamps at zero. It excludes opening positions, fees, cash, and historical market prices. Buying 100 then selling half for 80 leaves 20 on this chart, which is neither remaining cost basis nor market equity. A position bought before the selected range also has no opening value.

Fix: either rename/redefine it as a precisely specified trade-cashflow chart with appropriate signed flows, or compute portfolio equity using opening balances and historical valuation snapshots. Use complete history or correct period aggregates. Rename remaining position cost in the report instead of calling it cumulative invested capital.

Acceptance: test partial profitable/loss-making sales, fees, closed positions, and a date range starting after the original purchase.

**13. MEDIUM — Fresh installations lack profile creation**

Evidence: `20261011000001_baseline_tables.sql:10`; `lib/data/services/supabase_service.dart:37`; original signup trigger only in `../supabase_schema.sql:205`.

Fresh migrations do not install the original Auth-user-to-profile trigger, and mobile signup does not insert a profile. The local fresh-schema probe confirmed no profile after creating an Auth user. Financial rows referencing `profiles(id)` then fail for newly registered users. An upgraded installation may still work because the old trigger remains, making this easy to miss.

Fix: include a hardened profile bootstrap in the canonical migrations and safely backfill missing profiles. Keep it compatible with pre-MFA enrollment without exposing private financial profile fields.

Acceptance: register a user against a clean migration-only environment, confirm email, enroll TOTP, and create the first trade and salary allocation without manual SQL.

**14. MEDIUM — Account recovery is only partially implemented**

Evidence: `lib/data/services/supabase_service.dart:53`, `lib/main.dart:56`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`.

The app sends a password-reset email but has no password-recovery event routing or new-password `updateUser` flow. No corresponding mobile deep-link configuration was found. A user receiving the email does not have a complete recovery experience in this app. TOTP device-loss recovery and confirmation resend are also not completed by the current changes.

Fix: implement and document approved redirect URLs, mobile link handling, a recovery state and new-password form, and confirmation resend. Define device-loss recovery without bypassing MFA through a weak client-side switch or placing admin credentials in Flutter. Test expired and reused links and invalid sessions. Configure the deployed Supabase project as part of the delivery.

**15. MEDIUM — The database test suite can hide an oversell failure**

Evidence: `supabase/tests/database_test.sql:91` and `:92`.

If an oversell unexpectedly succeeds, the test raises its own 'TEST FAILED' exception inside a block that catches `WHEN OTHERS`; the catch then prints a notice and continues. An unrelated SQL failure can also be misreported as an acceptable rejection. The suite runs with administrative access and explicit `p_user_id`, so it does not exercise actual caller roles or JWT assurance. Its header mentions dual-asset and linked-salary scenarios that the body does not implement.

Fix: assert only the expected validation error and rethrow every other exception; place the unexpected-success assertion outside the catch block. Add real-role authorization tests, the above regression cases, atomic rollback checks, concurrent writes, edited coin/date scenarios, salary reconciliation, and upgrade fixtures. Replace the test-only user-ID escape path with realistic auth context.

Acceptance: deliberately disabling the oversell check must make the test suite fail. The suite must also fail if MFA checks or helper privilege revocations are removed.

**Additional release work**

- `android/app/build.gradle.kts:37` still signs release builds with the debug signing configuration. Configure a controlled release signing process before distribution.
- `lib/core/storage/secure_local_storage.dart:26` migrates every matching `sb-*` / `auth-token` preference into one session key. Restrict migration to the exact project/session key, validate before removing the legacy copy, namespace stored sessions by project, and test storage failure/recovery behavior.
- Disabling biometrics does not require reauthentication, security settings are global rather than account-scoped, and app-switcher privacy/device behavior has not been verified.
- One-satoshi positions are filtered out by the portfolio's strict `> 1e-8` threshold, while the RPC inventory helper permits an oversell tolerance of one quantity quantum. Define supported precision and use exact quantized inventory rules.
- The README does not yet provide the migration/deployment/recovery runbook needed to reproduce a fresh or upgraded installation. No Android/iOS release build or physical-device MFA/biometric/deep-link run was performed in this review.
- For the broader goal of managing all spending and investments, the new cashflow screen still does not provide a complete expenses/accounts ledger. After the blockers, prioritize account balances and transfers, expense categories/budgets, recurring transactions, reconciliation, and non-crypto asset types. Avoid adding them on top of the current disconnected local cashflow store.

**Antigravity handoff order**

1. Close findings 1–3 together: explicit RPC authorization, private helpers, RPC-only writes, and regression tests under real roles. Include the stable operation IDs in finding 7.
2. Build and verify the safe fresh/legacy migration path in findings 6 and 13. Preserve existing financial records and explicitly report unresolved legacy ambiguities.
3. Fix the account/session/lock boundary and replace the unowned cashflow cache (findings 4, 5, 9).
4. Repair currency provenance, prices, reporting, and export (findings 8, 10–12).
5. Finish account recovery, release setup, meaningful tests, and deployment instructions. Verify the actual deployed Supabase grants/settings and physical-device flows before declaring completion.

Keep Flutter + Supabase + Google Authenticator. These fixes do not require a separately hosted backend. Deliver implementation, additive migrations, regression results, and a list of remaining unverified deployment/device steps; do not mark phases complete solely because the existing 16 Flutter tests pass.
