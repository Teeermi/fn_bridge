CREATE TABLE IF NOT EXISTS `fn_logs` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `resource` VARCHAR(64) NOT NULL,
    `channel` VARCHAR(16) NOT NULL,
    `event` VARCHAR(64) NOT NULL,
    `server_id` INT UNSIGNED NULL DEFAULT NULL,
    `char_id` VARCHAR(64) NULL DEFAULT NULL,
    `char_name` VARCHAR(128) NULL DEFAULT NULL,
    `license` VARCHAR(64) NULL DEFAULT NULL,
    `x` DECIMAL(8,2) NULL DEFAULT NULL,
    `y` DECIMAL(8,2) NULL DEFAULT NULL,
    `z` DECIMAL(8,2) NULL DEFAULT NULL,
    `data` JSON NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `idx_fn_logs_event` (`event`, `created_at`),
    KEY `idx_fn_logs_char` (`char_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
