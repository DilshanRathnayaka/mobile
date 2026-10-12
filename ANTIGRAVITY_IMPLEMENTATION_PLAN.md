Implementation handoff for Antigravity — Flutter + Supabase

Prepared 11 October 2026. The owner confirmed that the deployed application consists of a Flutter mobile app and Supabase. Google Authenticator is the intended second factor. The sibling Node/Firebase/MongoDB server is outside the deployed architecture and outside this implementation scope.

Read `APP_REVIEW_2026-10-11.md` as supporting evidence, then inspect the current code before editing because some files changed during the review. Implement the corrective phases below in order. Preserve unrelated work and existing financial records. Produce working code, versioned Supabase migrations, tests, and deployment instructions. This document is an implementation plan; no fixes or database migrations have yet been applied by its author.

The baseline fixes are Phases 0–7. Phase 8 is the subsequent personal-finance feature milestone, not a prerequisite for completing the defect fixes. Complete the correctness and security work before expanding the product.

**Architecture and decisions to keep throughout implementation**

- Use Flutter, Riverpod, Supabase Auth, Supabase Postgres/RLS, and database RPC functions. Do not introduce a separate Node, Firebase, MongoDB, Express, or custom TOTP-validation server. Preserve the currently deployed Supabase project unless a separate development environment is needed.
- Google Authenticator generates TOTP codes; Supabase Auth enrolls factors and validates codes. Google Sign-In/OAuth is not required for this feature. Never validate TOTP by length, a hardcoded value, or a client-computed comparison.
- Recommended policy for this personal financial app: require verified TOTP MFA before access to private financial data. Implement this as database/API authorization and a matching UI gate. Keep authentication, MFA enrollment, recovery, and minimal profile bootstrap accessible before MFA so new users can enroll. This mandatory policy is a design recommendation for the handoff, not a claim about the existing deployed settings.
- Biometrics are a local device-unlock control on an existing authenticated session. They cannot create a Supabase session or substitute for TOTP when Supabase requires MFA.
- Supabase Postgres is authoritative for ownership, inventory validation, amounts, cost basis, and atomic monetary changes. Client validation improves the UI; it is never the only enforcement.
- Use only the project's publishable/anon key in Flutter. Do not place service-role keys, database passwords, or third-party secret API keys in the app or its build defines. An anon/publishable key is not itself a confidential credential.
- Baseline work does not need Edge Functions. An optional Supabase Edge Function can later handle an explicitly required admin-only action or a secret-key price feed; it stays within Supabase and must independently authenticate/authorize callers. Do not add it unless the implemented feature needs it.
- Keep the existing UI/theme where possible. Remove misleading security/financial claims while replacing the underlying behavior.

**Phase 0 — Establish the baseline and safe migration inputs**

Inspect `lib/main.dart`, `lib/providers/`, `lib/data/services/`, `lib/data/models/`, all relevant screens, `pubspec.yaml`, Android/iOS settings, and `../supabase_schema.sql`. Confirm the unused `ApiService` is not on an active path. Do not spend implementation time fixing the unused Node server.

Create or use one canonical Supabase migrations directory. If the repository has no Supabase project structure, use `supabase/migrations/` under the mobile workspace and document how to apply it. Do not merely overwrite the standalone schema file or assume `CREATE TABLE IF NOT EXISTS` upgrades existing tables.

Record the current analyzer/test results. The previous review's final run had no analyzer errors, one warning, two infos, and one passing smoke test; re-establish the baseline rather than assuming it remains unchanged. Determine whether the deployed schema differs from the local SQL when access is available.

Prepare a read-only data audit for duplicate salary deposits, missing links, invalid/negative trades, oversells, ambiguous currencies, zero-rounded token prices, and duplicate asset identities such as `btc`/`bitcoin`. Preserve raw rows, IDs, counts, and timestamps in a restricted backup. Do not infer original currency from the user's current display preference, a notes string, or magnitude alone. Records that cannot be reconstructed reliably must be presented for reconciliation.

Deliver: baseline findings, migration order, rollback/recovery instructions, and an explicit list of data requiring review. If Supabase access is unavailable, continue implementing locally and provide exact migration files and manual steps; distinguish prepared changes from applied changes.

Acceptance: current data can be restored, no live table is reset, and ambiguous records are identified without guessing their corrected values.

**Phase 1 — Implement actual Google Authenticator MFA and an auth gate**

Primary files: `lib/main.dart`, `lib/screens/auth/auth_screen.dart`, `lib/screens/profile_screen.dart`, `lib/providers/security_provider.dart`, and `lib/data/services/supabase_service.dart`. Introduce focused auth/MFA controller and screens if needed instead of adding more responsibilities to the general portfolio service.

Implement an explicit route/state flow: initializing → signed out → email confirmation if needed → MFA enrollment or challenge → local device unlock when enabled → ready. Private providers must not load while a gate is incomplete. Initialization/session errors must show retry/sign-in recovery without entering the main screen.

Enrollment:

- Use `supabase.auth.mfa.enroll(factorType: FactorType.totp)` with a useful account/issuer label supported by the installed SDK.
- Present the returned QR representation correctly and a manual setup key. Manual entry matters when Google Authenticator is on the same phone as this app. Treat the secret as temporary sensitive enrollment data; never send it to a third-party QR service.
- Ask for the current six-digit code and call `supabase.auth.mfa.challengeAndVerify(factorId: ..., code: ...)`.
- Mark the factor protected only after Supabase verification succeeds and the session's assurance level is sufficient. Preserve leading zeros in codes. Input-format validation alone is not verification.
- Clear the setup secret from app state after completion/cancellation, do not retain a “View secret” feature, and do not log it, tokens, passwords, or codes. Clean up abandoned unverified factors without removing verified ones.

Sign-in/session handling:

- After password sign-in, inspect verified factors and `getAuthenticatorAssuranceLevel()`. An `aal1` session needing MFA must remain on the challenge screen. Enter financial screens only after confirmed `aal2`.
- Restore existing valid `aal2` sessions without unnecessary TOTP prompts; still apply local app lock. Never use `currentUser != null` alone to authorize financial screens.
- React to `onAuthStateChange`, including refresh, sign-out, and recovery. Handle loading/errors explicitly and avoid briefly displaying private screens during startup.
- Remove the hardcoded sample secret, local `is2faEnabled` authority, fake verification, and “Enforce Single Login Method” behavior that treats password/biometrics/TOTP as interchangeable.
- Derive the security status from Supabase's verified factor/session state. A locally enabled flag must not grant access.

Factor replacement/recovery: provide “Replace authenticator” with fresh verification, verify the replacement before removing the old factor where supported, and refresh/re-evaluate the session after changes. Do not provide a switch that disables the final factor and continues to financial screens under the mandatory-MFA policy. Document a trusted project-owner recovery procedure for a lost authenticator. Never implement a universal bypass code or assume Supabase provides recovery codes without checking support. Document that issued access-token revocation/downgrade follows Supabase's token/session behavior; do not promise immediate invalidation solely because a local flag changed.

Existing users of the old sample secret need fresh enrollment unless Supabase already has a real verified factor. Do not import the shared sample secret as an individual user's factor.

Acceptance: random/incorrect codes are rejected by Supabase; expired codes outside the provider's permitted time window are rejected; a valid code upgrades assurance; cancellation and networking errors cannot reveal financial data; signup without an active session stays in confirmation/sign-in flow.

Official API references: [enroll](https://supabase.com/docs/reference/dart/auth-mfa-enroll), [challengeAndVerify](https://supabase.com/docs/reference/dart/auth-mfa-challengeandverify).

**Phase 2 — Enforce authorization in Supabase and isolate accounts on-device**

Write versioned RLS/grant migrations for every private table, view, RPC, and any later Storage objects. Financial reads require ownership plus the MFA assurance policy; mutation RPCs enforce equivalent checks. Minimize the profile information exposed for enrollment/bootstrap, since the existing profile also contains salary-related fields. Split private preferences from bootstrap identity if necessary.

Audit all existing permissive policies. Merely adding another permissive MFA policy can leave access through an older owner-only policy; replace or combine policies correctly and test effective behavior. Cover `USING`, `WITH CHECK`, reassignment of ownership, and anonymous access. Ensure reporting views do not bypass RLS through their owner privileges.

Recommended write boundary: revoke direct client DML on canonical monetary tables and derived holdings; expose narrow mutation RPCs. Because revoked DML would also break a plain invoker RPC, implement required write RPCs as deliberately constrained `SECURITY DEFINER` functions with `search_path = ''`, qualified relation names, explicit `auth.uid()`/MFA/ownership checks, and minimal privileges. Never trust a submitted user ID. Revoke default execution from PUBLIC/anon and grant only the intended entry points to authenticated users. Keep calculation/helper functions inaccessible as public RPC entry points. Prefer invoker functions for operations that can work safely with normal caller permissions.

In Flutter, key private providers/caches by user ID and an authentication-generation identifier. Dispose/invalidate all portfolio, transaction, salary, report, receipt, and offline state on sign-out/account change. Discard late responses from the previous generation. Apply the same behavior to pending refreshes and writes, not only visible widgets. A user B session must never render user A's cached data.

Acceptance: direct API requests with no session or only `aal1` cannot access financial data; user A cannot read/write user B's records even with `aal2`; financial RPCs cannot be invoked with another user ID; no direct holdings tampering; A→logout→B shows only B's data, including after delayed responses arrive.

Official guidance: [MFA enforcement](https://supabase.com/docs/guides/auth/auth-mfa), [database function security](https://supabase.com/docs/guides/database/functions).

**Phase 3 — Correct biometrics, session persistence, and account recovery**

Make every biometric failure/cancel/unsupported/error outcome remain locked. Unsupported devices should use an explicitly supported OS credential/account reauthentication path or leave biometrics disabled; never manufacture success. Configure `FlutterFragmentActivity` on Android and the required Face ID description on iOS. Check installed plugin instructions and the merged Android manifest rather than assuming dependency-supplied permissions are absent.

Prompt on cold launch when app lock is enabled. Obscure sensitive content on backgrounding; use a documented default background timeout such as 30 seconds before requiring unlock again. Track app-originated authentication dialogs so lifecycle transitions do not cause an endless re-prompt loop. Scope the setting to device/account and verify device authentication before enabling or disabling it.

Implement a Keychain/Keystore-backed Supabase `LocalStorage` adapter using a maintained Flutter package compatible with the installed toolchain. Plan one-time migration of the SDK's old preferences session, validate the restored session, and remove the old sensitive copy only after successful migration. Clear sessions on sign-out; keep backups from restoring usable credentials to an unintended device. Do not gate the networking client's storage reads behind a new biometric prompt on every token refresh.

Make balance privacy mode apply to all financial screens, and obscure app-switcher previews as platform support permits. Implement password reset and email confirmation/resend/deep-link handling. Preserve password whitespace rather than silently trimming passwords. Use user-friendly auth errors without exposing internal details.

Account deletion is a separate destructive action: provide an authenticated request flow. If completing it requires an Auth admin API, use a narrowly authorized Supabase Edge Function with recent MFA and secrets stored only in Supabase. Do not ship an admin key in Flutter. This optional endpoint does not require a separately hosted server.

Acceptance: biometric failure never unlocks; app-resume behavior matches the documented timeout; another account cannot inherit the prior account's lock state/data; reset/confirmation links work; device tests cover Android and iOS when those platforms are shipped. Report unavailable physical-device checks honestly.

**Phase 4 — Repair currency, asset identity, and decimal precision**

Primary files: `lib/providers/currency_provider.dart`, `lib/core/utils/formatters.dart`, salary/transaction screens, financial models, price services, and migrations.

Keep USD as the existing normalized reporting base during the repair to avoid an unnecessary global rebasing migration; offer LKR as the personal display/input default. Model these concepts separately:

- Original amount and currency entered by the user.
- Historical conversion rate with an explicit direction, e.g. `fx_to_base = base units per original-currency unit`.
- Rate timestamp/source and derived base amount.
- Current display/valuation conversion rate, which never rewrites the original entry.

Remove fixed rates presented as current. Support a clearly dated manual rate when an appropriate feed is not configured. Do not silently guess missing FX. Treat USDT and USD as different quote currencies. Changing the UI display currency must never mutate past transactions. Editing an entry starts with its original currency/amount, not a newly converted display value.

Use exact decimals for authoritative arithmetic and adequate Postgres NUMERIC precision for quantities, prices, fees, FX, and cost basis. Document bounds and rounding rules; consider NUMERIC(38,18) for quantities/prices where suitable. Preserve exact decimal strings through RPC request/response serialization and Dart models so JSON decoding does not first turn them into imprecise doubles. Restrict double conversion to chart coordinates or non-authoritative display work. Do not round small token prices or tiny balances to zero in storage or detailed views.

Create canonical assets and explicit provider mappings: internal asset ID, symbol/name, CoinGecko ID, Binance pair, and chain/contract where applicable. Stop deriving a CoinGecko ID from a lowercase ticker. Resolve/migrate `btc` versus `bitcoin` with audited mappings; do not globally merge by symbol because symbols can collide. Preserve references and rebuild holdings after approved mappings.

Existing mixed-currency rows, duplicate asset identities, and values already rounded away must retain their raw provenance and be flagged for reconciliation. Do not automatically divide all historical amounts by 305. Totals with unresolved entries must disclose incomplete coverage rather than invent precise results.

Acceptance: an LKR 10,000 entry still displays LKR 10,000 on save/reopen/edit; currency switching does not alter stored facts; an explicit test rate produces the expected USD base amount; a price of 0.00001045 survives a database round trip; BTC maps consistently across entry and valuation; USDT conversion is explicit.

**Phase 5 — Make ledger changes atomic and correct holdings/P&L**

Implement a single canonical set of database operations. Suggested entry points are `create_trade`, `update_trade`, `delete_trade` or an equivalent reversal operation, `save_salary_allocation`, and `delete_salary_allocation`. Names may follow existing conventions; semantics below are required.

Each monetary RPC derives the actor from the session, authorizes the request, validates all inputs, obtains a per-user transaction-scoped lock, changes the ledger, updates derived data, and returns the affected IDs/version as one database transaction. A per-user row/advisory lock is a simple starting point for this personal app; every mutation path must use the same locking protocol. Move to finer locks only with deterministic ordering and concurrency tests.

Accept an operation UUID and expected record version. Enforce unique `(user_id, operation_id)` semantics; retries return the prior result and reuse with different content is rejected. Prevent concurrent devices from silently overwriting each other's edits. A request that fails any step leaves no partial records. Report no-op/not-found/version-conflict distinctly rather than returning success regardless of affected rows.

Salary allocation rules:

- Preserve one allocation per user/month and one linked actual deposit for the existing “record salary inflow” workflow. Add a real foreign-key relationship and uniqueness; a note string is not a link.
- Re-saving the same operation creates nothing extra. Editing updates the linked deposit consistently. Deleting reverses/removes the linked effect consistently with an audit trail.
- Model the chosen effective date explicitly; do not timestamp an old month's deposit as today by accident. Use a validated month/date picker and store timestamps in UTC, displaying them in the user's timezone.
- Keep planned budget allocations distinct from actual deposits. A future planning-only record must not create a cash deposit.
- Keep the form open on failure, prevent double taps, and refresh affected transaction, salary, portfolio, and report providers after confirmed success.

Trade/holding rules:

- Reject nonfinite/negative values, invalid quantities/fees, unknown assets/currencies, and inconsistent transaction types. Derive total amounts in the database. Validate inventory at every point in chronological history, including after backdating, editing, or deleting a previous buy.
- Reject oversells; never clamp a negative quantity to zero. Short selling is outside this app's current scope.
- Use the existing weighted-average-cost approach, with documented fee treatment and deterministic transaction ordering, including a tie-breaker. Editing/moving an asset recalculates both old and new assets. Maintain one calculation implementation; retire the old trigger path if RPC processing replaces it, or have the canonical trigger/helper operate under the RPC lock.
- Aggregate realized P&L across all closed and open holdings. Open-position visibility must not determine whether historical profit exists.
- Label remaining open-position cost basis separately from lifetime contributions or buys. Build aggregates in the database independently of paginated UI lists.
- Preserve an audit of edits/deletions/reversals with actor and time. Protect audit records from client alteration.

Reconcile old duplicate salary entries and rebuild holdings from the corrected canonical ledger. Do not delete uncertain duplicates solely because amounts match; retain enough information to distinguish two real deposits.

Acceptance: buy 1 at $100 then sell 1 at $120 yields quantity 0 and realized P&L $20 before fees; buy 1 then sell 2 is rejected; moving BTC→ETH leaves neither a stale BTC balance nor double-counted value; edit/delete/backdate checks retain valid inventory; repeated salary saves create one linked deposit; simulated failure commits nothing; simultaneous oversells cannot both succeed.

**Phase 6 — Make prices, charts, errors, export, and recovery truthful**

Primary files: `lib/data/services/binance_service.dart`, `lib/data/services/supabase_service.dart`, analytics/dashboard/history screens, and associated providers.

Replace mock price fallbacks and purchase-price substitutions with a typed quote carrying value, quote currency, provider, observation time, and freshness. On failure retain a dated last-good quote marked stale or mark valuation unavailable. A partial portfolio valuation must show its coverage; unknown assets must not look like zero-valued holdings or break-even positions. Handle timeouts/rate limits, deduplicate requests, and bound retry/backoff. Demo fixtures belong only in explicitly labeled demo/test mode.

Propagate read/write failures as typed errors. Distinguish initial loading, truly empty data, stale cached data, partial data, and errors with retry. Do not turn an API error into an empty account. If offline writes are not implemented yet, say they are unsaved; never show success for a memory-only or failed write.

Remove fabricated chart points. Render actual dated snapshots/historical valuations and make range selection actually filter the data. Do not invent history before collection began; show “insufficient history.” If snapshots are collected only when the app runs, label that frequency and show gaps. A reliable daily background series requires an explicitly designed Supabase scheduled job/feed; do not claim the phone collects data daily while closed. Separate deposits/withdrawals from market returns.

Add cursor/range pagination with stable ordering to history and exports. Database summary aggregates must include all records, not only the current page. Implement actual CSV file creation/sharing with original/base currencies, timestamps, account/asset identifiers, fees, and stable IDs. Protect exported text fields from spreadsheet-formula injection. Cancelled/failed exports must not display success.

Add a versioned backup/restore format for supported financial data, excluding credentials and authenticator secrets. Validate imports, preview counts/conflicts, use idempotency, and reconcile restored balances; encrypt private backups with a documented recovery approach. Test restoration into an empty test account. Define the baseline restore policy as complete atomic import for bounded backups, or explicit staged resumable import for larger files; never leave a silent partial restore.

Acceptance: network failure produces no invented prices/graphs/zero balances; changing chart range changes actual observations; exports include more than 1,000 test records correctly; export/save errors remain visible; backup→restore matches verified source totals and does not duplicate records on retry.

**Phase 7 — Release readiness, tests, and deployment evidence**

Add INTERNET permission to the Android main manifest and inspect the release merged manifest. Replace release debug signing with a release/upload-key configuration whose private material stays outside source control. Complete app label/icon/configuration, iOS Face ID description, and configured auth deep links. Verify dependency versions before adding packages and keep the scope of upgrades tied to the fixes.

Use separate dev/test and production configuration with the correct Supabase project and public key. Build defines organize configuration; they cannot hide secrets from a mobile binary. Fix relevant analyzer warnings and require tests that demonstrate the defects are fixed, rather than tests that only mirror implementation.

Run unit/widget tests for the auth state machine, decimal/currency transformations, forms, provider isolation, quote states, and export behavior. Run database tests and two-account integration tests against a disposable Supabase environment; service-role test setup must not be confused with testing real authenticated permissions. Include adversarial direct API calls using anon, `aal1`, user A `aal2`, and user B `aal2` credentials.

Minimum regression matrix:

| Scenario | Required result |
| --- | --- |
| Random/expired TOTP, cancelled setup, no network | Private data stays inaccessible |
| Valid Google Authenticator enrollment/sign-in | Server verification yields required assurance |
| Direct API/RPC access before MFA or as another user | Denied, including views/helper functions |
| Restart/resume, biometric error, token expiry | Correct auth/app-lock gate without private-screen flash |
| User A logout → B login with delayed A response | No A data displayed or cached for B |
| LKR original amount and historical FX round-trip | Original amount preserved; no second conversion |
| Very small asset price and quantity | Exact stored values survive round-trip |
| Duplicate salary submit, edit, delete, forced failure | One consistent linked deposit; atomic effects |
| Full sale, fees, asset change, backdating/deletion | Correct cost basis and retained realized P&L |
| Oversell and two concurrent sell requests | Invalid inventory never committed |
| Wrong asset mapping / missing quote | Explicit unavailable valuation; no fake break-even |
| More than 1,000 transactions and date boundaries | Complete aggregate/export and correct local dates |
| Price/read/write outage and retry | Truthful UI and no duplicate committed mutation |
| Backup/restore with duplicates/corrupt input | Verified reconciliation or explicit rejection |
| Android release build and physical biometrics | Network/auth/unlock work in the shipped variant |

Deliver a release note identifying changed files, migration order, data reconciliation actions, test commands/results, and manual Supabase settings. Mark checks that could not run as pending with the exact reason. Do not describe local tests as production RLS validation. Before changing live data, have a concrete backup, tested migration, reconciliation summary, and rollback/recovery procedure. Apply production changes only within the owner's deployment authorization; prepared SQL is not an applied migration.

Completion of Phases 0–7 means the existing app no longer relies on fake security, guessed financial values, or inconsistent writes, with evidence from both client and database tests.

**Phase 8 — Personal-finance expansion after the baseline is correct**

Implement this as the next product milestone when requested. Keep it separate from the defect-fix acceptance criteria so security/accounting repairs can be completed and reviewed first.

Recommended sequence: accounts and opening balances → income/expenses/transfers → categories/budgets/recurring bills → additional assets/liabilities → savings goals → offline queue and statement import → broader reports.

Use accounts for bank/cash/wallet/exchange/credit card, transactions and balanced postings to describe movements, categories for expenses/income, and asset-specific investment events linked to postings. A transfer between owned accounts must not inflate income/expense or net worth; a fee should reduce value separately. Salaries increase cash, purchases exchange cash for an investment, and price changes affect unrealized P&L. Represent FX transfers with their actual amounts in both currencies and explicit fees.

Track FD maturity/interest, shares/funds/dividends, manual assets, loans and credit-card liabilities. Do not promise automatic integrations until a reliable source is implemented. Add month budgets, bill reminders, emergency-fund goals, reconciliation, and receipts with private Storage policies. Preserve the per-user/MFA controls for all new objects.

Prioritize Overview, Transactions, Accounts, Investments, and Reports navigation. The overview should show available cash, monthly income/expenses, remaining budget, upcoming bills, and assets minus liabilities. Add offline capture only with account-scoped encrypted storage, pending/failed/conflict states, operation IDs, and version-aware sync; pending writes must never be silently assigned to whichever account logs in next.

**How Antigravity should report progress**

Work through Phases 0–7 in dependency order, checking the current code rather than blindly applying review line numbers. For each phase report the actual behavior changed, files/migrations produced, relevant test evidence, and remaining blockers. Do not call a phase complete because the UI looks finished. If production access or a physical device is missing, finish all available implementation and provide exact pending actions without inventing successful deployment. Do not implement Phase 8 during the defect-fix milestone unless the owner asks for the feature expansion.
