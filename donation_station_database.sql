-- Donation Station database
-- Designed from the current Donation Station HTML/JavaScript fields.
-- MySQL 8+ / compatible with Laravel migrations later.
-- This schema stores financial donations only.

CREATE DATABASE IF NOT EXISTS donation_station
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE donation_station;

-- 1. Registered users
CREATE TABLE users (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    phone VARCHAR(30) NULL,
    password VARCHAR(255) NOT NULL COMMENT 'Store a server-side password hash, never a plain password',
    role ENUM('donor', 'admin') NOT NULL DEFAULT 'donor',
    terms_accepted_at TIMESTAMP NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY users_email_unique (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Cases shown on the current site
CREATE TABLE cases (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    target_amount DECIMAL(12,2) NOT NULL,
    collected_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    status ENUM('active', 'completed', 'cancelled') NOT NULL DEFAULT 'active',
    emoji VARCHAR(16) NOT NULL DEFAULT '❤️',
    category ENUM('food', 'education', 'health', 'housing', 'other') NOT NULL DEFAULT 'other',
    location VARCHAR(255) NOT NULL,
    created_by BIGINT UNSIGNED NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY cases_status_index (status),
    KEY cases_category_index (category),
    KEY cases_created_by_index (created_by),
    CONSTRAINT cases_target_amount_positive CHECK (target_amount > 0),
    CONSTRAINT cases_collected_amount_nonnegative CHECK (collected_amount >= 0),
    CONSTRAINT cases_created_by_foreign
        FOREIGN KEY (created_by) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Donations made to cases. Donor details are kept as a snapshot,
-- so guest donations and historical records remain possible.
CREATE TABLE donations (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    case_id BIGINT UNSIGNED NOT NULL,
    donor_user_id BIGINT UNSIGNED NULL,
    donor_name VARCHAR(200) NOT NULL,
    donor_email VARCHAR(255) NOT NULL,
    donor_phone VARCHAR(30) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'EGP',
    payment_method ENUM('card', 'bank', 'wallet', 'mobile') NOT NULL,
    message TEXT NULL,
    status ENUM('pending', 'completed', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
    donated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY donations_case_id_index (case_id),
    KEY donations_donor_user_id_index (donor_user_id),
    KEY donations_status_index (status),
    KEY donations_donated_at_index (donated_at),
    CONSTRAINT donations_amount_positive CHECK (amount > 0),
    CONSTRAINT donations_case_foreign
        FOREIGN KEY (case_id) REFERENCES cases(id)
        ON DELETE RESTRICT,
    CONSTRAINT donations_user_foreign
        FOREIGN KEY (donor_user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Optional payment-provider records for when real online payments are added.
-- The current front end only selects a payment method; it does not verify payments.
CREATE TABLE payment_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    donation_id BIGINT UNSIGNED NOT NULL,
    provider VARCHAR(100) NULL,
    provider_reference VARCHAR(255) NULL,
    amount DECIMAL(12,2) NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'EGP',
    status ENUM('pending', 'successful', 'failed', 'refunded') NOT NULL DEFAULT 'pending',
    paid_at TIMESTAMP NULL,
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY payment_provider_reference_unique (provider_reference),
    KEY payment_transactions_donation_id_index (donation_id),
    KEY payment_transactions_status_index (status),
    CONSTRAINT payment_amount_positive CHECK (amount > 0),
    CONSTRAINT payment_transactions_donation_foreign
        FOREIGN KEY (donation_id) REFERENCES donations(id)
        ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Contact messages (optional site feature)
CREATE TABLE contact_messages (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NULL,
    name VARCHAR(200) NOT NULL,
    email VARCHAR(255) NOT NULL,
    subject VARCHAR(200) NULL,
    message TEXT NOT NULL,
    status ENUM('unread', 'read', 'replied') NOT NULL DEFAULT 'unread',
    created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY contact_messages_status_index (status),
    CONSTRAINT contact_messages_user_foreign
        FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Important implementation notes:
-- 1. Insert password hashes created by Laravel Hash::make(), never browser-side btoa().
-- 2. A donation must not be marked completed until the server verifies the payment.
-- 3. Update cases.collected_amount transactionally from verified completed donations,
--    or calculate the total from donations where status = 'completed'.
-- 4. Use Laravel migrations as the long-term schema source once backend development begins.
