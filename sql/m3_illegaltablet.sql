CREATE TABLE IF NOT EXISTS `m3_tablet` (
  `identifier`       varchar(60)  NOT NULL,
  `name`             varchar(60)  NOT NULL DEFAULT '',
  `boosting_xp`      int          NOT NULL DEFAULT 0,
  `burglary_xp`      int          NOT NULL DEFAULT 0,
  `contract_filter`  longtext     NOT NULL DEFAULT '[]',
  `offers`           longtext     NOT NULL DEFAULT '[]',
  `next_rotation`    int          NOT NULL DEFAULT 0,
  `player_id`        int          NOT NULL DEFAULT 0,
  PRIMARY KEY (`identifier`),
  UNIQUE KEY `idx_player_id` (`player_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

