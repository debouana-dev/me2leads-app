-- ============================================================
-- Me2Leads — Dummy test data  (MySQL 8.0+)
-- ============================================================
-- HOW TO USE
-- ----------
-- Option A (recommended): create the account normally through the
--   app (which encrypts PII with the device key), then run the
--   UPDATE at the bottom to promote it to the 'business' plan.
--
-- Option B: insert the full row below. Because PII columns are
--   AES-256-CBC encrypted with a per-device master key stored in
--   Android Keystore / iOS Keychain, the placeholder ciphertext
--   here will NOT decrypt in the app. Use this only to verify
--   plan-gating UI / organization flows without needing a real
--   login; combine with the UPDATE approach for a fully functional
--   test account.
--
-- Password hashing algorithm (EncryptionService.hashPassword):
--   salt  = base64(16 random bytes)
--   hash  = SHA-256(salt + ":" + password)   — hex string
--   stored as "salt:hash"
-- The test password below is:  TestBusiness@2026
-- ============================================================

SET NAMES utf8mb4;

-- ============================================================
-- OPTION A — promote an existing test account to 'business'
-- Replace the email_lookup value with the one for your account.
-- To find it: SELECT id, email_lookup, plan FROM users;
-- ============================================================
-- UPDATE `users`
--   SET `plan` = 'business',
--       `last_sync_at` = NOW()
--   WHERE `id` = '<your-test-user-id>';


-- ============================================================
-- OPTION B — full INSERT for a standalone dummy business account
--
-- Fixed UUIDs (safe to reuse across test environments):
--   User  : a1b2c3d4-e5f6-7890-abcd-ef1234567890
--
-- _enc values are intentional placeholders; they are valid
-- base64 but not encrypted with any real device key.
-- Swap them for real encrypted values if you need the app to
-- display the contact's name / email / phone correctly.
-- ============================================================
INSERT INTO `users` (
  `id`,
  `email_enc`,
  `email_lookup`,
  `first_name_enc`,
  `last_name_enc`,
  `nickname_enc`,
  `phone_enc`,
  `phone_lookup`,
  `company_name_enc`,
  `company_role_enc`,
  `biography_enc`,
  `password_hash`,
  `auth_provider`,
  `session_token`,
  `created_at`,
  `last_login_at`,
  `password_changed_at`,
  `photo_path`,
  `email_verified`,
  `organization_id`,
  `org_role`,
  `plan`,
  `last_sync_at`
) VALUES (
  'a1b2c3d4-e5f6-7890-abcd-ef1234567890',   -- id

  -- email_enc  ← placeholder for test@me2leads.dev
  'VEVTVC9lbWFpbC9wbGFjZWhvbGRlcj09',

  -- email_lookup = SHA-256(salt::test@me2leads.dev) — placeholder
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',

  -- first_name_enc  ← placeholder for "Test"
  'VEVTVC9maXJzdC9uYW1lL3BsYWNlaG9sZGVy',

  -- last_name_enc   ← placeholder for "Business"
  'VEVTVC9sYXN0L25hbWUvcGxhY2Vob2xkZXI=',

  NULL,   -- nickname_enc

  -- phone_enc  ← placeholder for +33600000000
  'VEVTVC9waG9uZS9wbGFjZWhvbGRlcg==',

  -- phone_lookup  ← placeholder
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',

  -- company_name_enc  ← placeholder for "Me2Leads Test Corp"
  'VEVTVC9jb21wYW55L3BsYWNlaG9sZGVy',

  -- company_role_enc  ← placeholder for "QA Engineer"
  'VEVTVC9yb2xlL3BsYWNlaG9sZGVy',

  NULL,   -- biography_enc

  -- password_hash for password:  TestBusiness@2026
  -- Format: base64(salt) + ":" + sha256(salt + ":" + password)
  -- Generated via EncryptionService.hashPassword("TestBusiness@2026")
  -- Replace with output of:
  --   dart run tool/gen_password_hash.dart TestBusiness@2026
  -- Or register through the app and copy the stored hash.
  'dGVzdFNhbHRCdXNpbmVzcw==:0000000000000000000000000000000000000000000000000000000000000000',

  'email',   -- auth_provider
  NULL,      -- session_token (populated on first login)

  '2026-05-04 10:00:00',   -- created_at
  NULL,                    -- last_login_at
  '2026-05-04 10:00:00',   -- password_changed_at

  NULL,    -- photo_path
  1,       -- email_verified  (1 = verified, skip the code step)
  NULL,    -- organization_id  (set if testing org flows)
  NULL,    -- org_role

  'business',   -- plan  ← the column under test

  NULL     -- last_sync_at
)
ON DUPLICATE KEY UPDATE
  `plan`         = 'business',
  `last_sync_at` = NOW();


-- ============================================================
-- QUICK PLAN-UPGRADE SNIPPET
-- Run this after Option A (account already exists in DB):
-- ============================================================
-- UPDATE `users`
--   SET `plan`         = 'business',
--       `last_sync_at` = NOW()
--   WHERE `email_lookup` = '<paste email_lookup from SELECT above>';
