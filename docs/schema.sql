-- ============================================================
-- myleads  —  Database schema v11
-- MySQL 8.0+  ·  InnoDB  ·  utf8mb4_unicode_ci
-- Derived from lib/services/database_service.dart
--
-- Notes:
--   · PK values are UUID v4 strings (36 chars).
--   · _enc columns hold AES-256-CBC cipher text (base64); may be long.
--   · _lookup columns hold hex-encoded SHA-256(salt::normalizedValue)
--     used for uniqueness checks without decrypting the stored value.
--   · TINYINT(1) is the canonical MySQL boolean: 0 = false, 1 = true.
--   · Partial-index semantics from SQLite are preserved via MySQL's
--     native NULL handling in UNIQUE keys (multiple NULLs allowed).
--   · JSON columns require MySQL 8.0.13+ for expression defaults;
--     the application always supplies a value on INSERT.
-- ============================================================

SET NAMES utf8mb4;
SET foreign_key_checks = 0;

-- ============================================================
-- USERS
-- Sensitive PII columns are AES-256-CBC encrypted (_enc suffix).
-- Lookup columns store deterministic SHA-256 hashes for
-- uniqueness queries without decrypting the stored value.
-- ============================================================
CREATE TABLE IF NOT EXISTS `users` (
  `id`                   VARCHAR(36)   NOT NULL,
  `email_enc`            TEXT          NOT NULL,
  `email_lookup`         CHAR(64)      NOT NULL        COMMENT 'SHA-256(salt::normalizedEmail)',
  `first_name_enc`       TEXT          NOT NULL,
  `last_name_enc`        TEXT          NOT NULL,
  `nickname_enc`         TEXT          DEFAULT NULL,
  `phone_enc`            TEXT          DEFAULT NULL,
  `phone_lookup`         CHAR(64)      DEFAULT NULL    COMMENT 'SHA-256(salt::normalizedPhone)',
  `date_of_birth_enc`    TEXT          DEFAULT NULL    COMMENT 'kept for schema compat; no longer written (doc v7)',
  `company_name_enc`     TEXT          DEFAULT NULL,
  `company_role_enc`     TEXT          DEFAULT NULL,
  `biography_enc`        TEXT          DEFAULT NULL,
  `password_hash`        VARCHAR(255)  NOT NULL        COMMENT 'SHA-256 with salt',
  `auth_provider`        VARCHAR(50)   NOT NULL DEFAULT 'email',
  `session_token`        VARCHAR(255)  DEFAULT NULL,
  `created_at`           DATETIME      NOT NULL,
  `last_login_at`        DATETIME      DEFAULT NULL,
  `password_changed_at`  DATETIME      NOT NULL        COMMENT 'rotated on every password change',
  `photo_path`           TEXT          DEFAULT NULL,
  `email_verified`       TINYINT(1)    NOT NULL DEFAULT 0,
  `organization_id`      VARCHAR(36)   DEFAULT NULL    COMMENT 'FK to organizations.id (nullable)',
  `org_role`             VARCHAR(20)   DEFAULT NULL    COMMENT 'admin | member | NULL',
  `plan`                 VARCHAR(20)   NOT NULL DEFAULT 'free' COMMENT 'free | premium | business',
  `last_sync_at`         DATETIME      DEFAULT NULL            COMMENT 'ISO-8601 timestamp of last successful MySQL sync (v11)',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email_lookup` (`email_lookup`),
  UNIQUE KEY `uq_users_phone_lookup` (`phone_lookup`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- CONTACTS
-- phone and email are stored as plaintext in the app model but
-- _lookup columns hold SHA-256 hashes for duplicate detection.
--
-- The composite UNIQUE keys on (owner_id, *_lookup) rely on
-- MySQL's built-in NULL semantics: multiple rows with a NULL
-- lookup column are permitted, matching SQLite partial-index
-- behavior.
-- ============================================================
CREATE TABLE IF NOT EXISTS `contacts` (
  `id`                VARCHAR(36)   NOT NULL,
  `owner_id`          VARCHAR(36)   NOT NULL,
  `first_name`        VARCHAR(255)  NOT NULL,
  `last_name`         VARCHAR(255)  NOT NULL,
  `job_title`         VARCHAR(255)  DEFAULT NULL,
  `company`           VARCHAR(255)  DEFAULT NULL,
  `phone`             VARCHAR(50)   DEFAULT NULL,
  `email`             VARCHAR(320)  DEFAULT NULL,
  `phone_lookup`      CHAR(64)      DEFAULT NULL    COMMENT 'SHA-256(salt::normalizedPhone)',
  `email_lookup`      CHAR(64)      DEFAULT NULL    COMMENT 'SHA-256(salt::normalizedEmail)',
  `source`            VARCHAR(100)  DEFAULT NULL,
  `project_1`         VARCHAR(255)  DEFAULT NULL,
  `project_1_budget`  VARCHAR(100)  DEFAULT NULL,
  `project_2`         VARCHAR(255)  DEFAULT NULL,
  `project_2_budget`  VARCHAR(100)  DEFAULT NULL,
  `interest`          TEXT          DEFAULT NULL,
  `notes`             TEXT          DEFAULT NULL,
  `tags`              JSON          DEFAULT NULL    COMMENT 'JSON array e.g. ["vip","client"]',
  `status`            VARCHAR(20)   NOT NULL DEFAULT 'warm' COMMENT 'hot | warm | cold',
  `created_at`        DATETIME      NOT NULL,
  `last_contact_date` DATETIME      DEFAULT NULL,
  `avatar_color`      VARCHAR(20)   DEFAULT NULL,
  `capture_method`    VARCHAR(20)   NOT NULL DEFAULT 'manual' COMMENT 'manual | scan | qr | nfc',
  `photo_path`        TEXT          DEFAULT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_contacts_owner` (`owner_id`),
  UNIQUE KEY `uq_contacts_owner_phone` (`owner_id`, `phone_lookup`),
  UNIQUE KEY `uq_contacts_owner_email` (`owner_id`, `email_lookup`),
  CONSTRAINT `fk_contacts_owner`
    FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- REMINDERS  (v5 schema: multi-contact + scheduling)
-- contact_ids is a JSON array; contact_id mirrors the first
-- element for backwards-compat with pre-v5 rows.
-- priority_v2 is the canonical priority; the legacy columns
-- (title, description, due_date, priority) are kept for
-- migration safety only and are not read by the app.
-- ============================================================
CREATE TABLE IF NOT EXISTS `reminders` (
  `id`               VARCHAR(36)   NOT NULL,
  `owner_id`         VARCHAR(36)   NOT NULL,
  `contact_id`       VARCHAR(36)   DEFAULT NULL   COMMENT 'legacy: first element of contact_ids',
  `contact_ids`      JSON          NOT NULL       COMMENT 'JSON array of contact IDs',
  `start_date_time`  DATETIME      NOT NULL,
  `end_date_time`    DATETIME      DEFAULT NULL   COMMENT 'NULL = no end',
  `repeat_frequency` VARCHAR(20)   DEFAULT NULL   COMMENT 'e.g. 1d | 1w | 1mo | NULL',
  `note`             TEXT          NOT NULL,
  `todo_action`      VARCHAR(20)   NOT NULL DEFAULT 'call' COMMENT 'call | sms | whatsapp | email',
  `priority_v2`      VARCHAR(30)   NOT NULL DEFAULT 'normal' COMMENT 'very_important | important | normal',
  -- legacy columns (kept for migration compat, not read by the app)
  `title`            VARCHAR(255)  DEFAULT NULL,
  `description`      TEXT          DEFAULT NULL,
  `due_date`         DATETIME      DEFAULT NULL,
  `priority`         VARCHAR(20)   DEFAULT NULL   COMMENT 'urgent | soon | later',
  `is_completed`     TINYINT(1)    NOT NULL DEFAULT 0,
  `created_at`       DATETIME      NOT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_reminders_owner` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- INTERACTIONS
-- Audit log for contact actions (call, sms, whatsapp, email,
-- note) and field-level edits (type = 'edit').
-- ============================================================
CREATE TABLE IF NOT EXISTS `interactions` (
  `id`          VARCHAR(36)  NOT NULL,
  `owner_id`    VARCHAR(36)  NOT NULL,
  `contact_id`  VARCHAR(36)  NOT NULL,
  `type`        VARCHAR(20)  NOT NULL COMMENT 'call | sms | whatsapp | email | note | edit',
  `content`     TEXT         NOT NULL,
  `created_at`  DATETIME     NOT NULL,

  PRIMARY KEY (`id`),
  KEY `idx_interactions_contact` (`contact_id`),
  CONSTRAINT `fk_interactions_owner`
    FOREIGN KEY (`owner_id`)   REFERENCES `users`    (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_interactions_contact`
    FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- PAYMENT METHODS
-- Full card / payment details are AES-256 encrypted in
-- encrypted_details.
-- ============================================================
CREATE TABLE IF NOT EXISTS `payment_methods` (
  `id`                 VARCHAR(36)   NOT NULL,
  `owner_id`           VARCHAR(36)   NOT NULL,
  `type`               VARCHAR(20)   NOT NULL COMMENT 'card | bank-transfer | ...',
  `label`              VARCHAR(255)  NOT NULL,
  `encrypted_details`  TEXT          NOT NULL,
  `created_at`         DATETIME      NOT NULL,

  PRIMARY KEY (`id`),
  CONSTRAINT `fk_payment_methods_owner`
    FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- SESSION  (single-row key/value store for the active session)
-- ============================================================
CREATE TABLE IF NOT EXISTS `session` (
  `key`    VARCHAR(100)  NOT NULL,
  `value`  TEXT          NOT NULL,

  PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- NOTIFICATIONS  (v6)
-- In-app notification inbox. reference_id points to the related
-- entity (contact, reminder) when applicable.
-- ============================================================
CREATE TABLE IF NOT EXISTS `notifications` (
  `id`            VARCHAR(36)   NOT NULL,
  `owner_id`      VARCHAR(36)   NOT NULL,
  `type`          VARCHAR(50)   NOT NULL,
  `title`         VARCHAR(255)  NOT NULL,
  `body`          TEXT          NOT NULL,
  `scheduled_at`  DATETIME      NOT NULL,
  `created_at`    DATETIME      NOT NULL,
  `reference_id`  VARCHAR(36)   DEFAULT NULL,
  `is_read`       TINYINT(1)    NOT NULL DEFAULT 0,

  PRIMARY KEY (`id`),
  KEY `idx_notifications_owner` (`owner_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- ORGANIZATIONS  (v7)
-- invite_code is the 8-char alphanumeric join code shown in the UI.
-- Characters drawn from [A-Z2-9] (no 0/O/1/I ambiguity).
-- owner_id is not enforced as a FK to allow flexible delete order.
-- ============================================================
CREATE TABLE IF NOT EXISTS `organizations` (
  `id`           VARCHAR(36)   NOT NULL,
  `name`         VARCHAR(255)  NOT NULL,
  `owner_id`     VARCHAR(36)   NOT NULL COMMENT 'references users.id; not FK-enforced',
  `invite_code`  CHAR(8)       NOT NULL,
  `created_at`   DATETIME      NOT NULL,

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_organizations_invite_code` (`invite_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- ORGANIZATION MEMBERS  (v7 + v8 privileges + v10 reminder access)
-- can_edit / can_create / can_view_reminders are per-member flags;
-- admins (role = 'admin') always get all three regardless of the
-- stored value.
-- ============================================================
CREATE TABLE IF NOT EXISTS `organization_members` (
  `id`                  VARCHAR(36)  NOT NULL,
  `organization_id`     VARCHAR(36)  NOT NULL,
  `user_id`             VARCHAR(36)  NOT NULL,
  `role`                VARCHAR(20)  NOT NULL DEFAULT 'member' COMMENT 'admin | member',
  `status`              VARCHAR(20)  NOT NULL DEFAULT 'active' COMMENT 'active | inactive',
  `joined_at`           DATETIME     NOT NULL,
  `can_edit`            TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'overridden to 1 for role=admin',
  `can_create`          TINYINT(1)   NOT NULL DEFAULT 1 COMMENT 'overridden to 1 for role=admin',
  `can_view_reminders`  TINYINT(1)   NOT NULL DEFAULT 0 COMMENT 'overridden to 1 for role=admin',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_org_members_org_user` (`organization_id`, `user_id`),
  KEY `idx_org_members_org`  (`organization_id`),
  KEY `idx_org_members_user` (`user_id`),
  CONSTRAINT `fk_org_members_org`
    FOREIGN KEY (`organization_id`) REFERENCES `organizations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_org_members_user`
    FOREIGN KEY (`user_id`)         REFERENCES `users`         (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


SET foreign_key_checks = 1;


-- ============================================================
-- INCREMENTAL MIGRATIONS  (run against an existing database)
-- Each block is idempotent: safe to re-run on a DB that already
-- has the column / index.  Apply in version order.
-- ============================================================

-- v8: per-member access privileges
ALTER TABLE `organization_members`
  ADD COLUMN IF NOT EXISTS `can_edit`   TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS `can_create` TINYINT(1) NOT NULL DEFAULT 1;
UPDATE `organization_members` SET `can_edit` = 1, `can_create` = 1 WHERE `role` = 'admin';

-- v9: subscription plan
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `plan` VARCHAR(20) NOT NULL DEFAULT 'free'
    COMMENT 'free | premium | business';

-- v10: per-member reminder-view privilege
ALTER TABLE `organization_members`
  ADD COLUMN IF NOT EXISTS `can_view_reminders` TINYINT(1) NOT NULL DEFAULT 0;
UPDATE `organization_members` SET `can_view_reminders` = 1 WHERE `role` = 'admin';

-- v11: per-user last-sync timestamp
ALTER TABLE `users`
  ADD COLUMN IF NOT EXISTS `last_sync_at` DATETIME DEFAULT NULL
    COMMENT 'Timestamp of last successful MySQL sync for this user';

-- Widen invite_code from CHAR(6) to CHAR(8) to match the app generator.
-- (Previously documented as 6-char; the app has always generated 8 chars.)
ALTER TABLE `organizations`
  MODIFY COLUMN `invite_code` CHAR(8) NOT NULL;


-- ============================================================
-- Schema version history
-- ============================================================
-- v1–4  : Original contacts / reminders / users schema
-- v5    : Multi-contact reminders + scheduling columns
-- v6    : In-app notifications table
-- v7    : organizations + organization_members tables; org columns on users
-- v8    : Per-member can_edit / can_create privilege columns
-- v9    : users.plan subscription tier column
-- v10   : organization_members.can_view_reminders privilege column
-- v11   : users.last_sync_at — per-user timestamp of last successful sync
--         + correct invite_code width to CHAR(8)
-- ============================================================
