CREATE TABLE IF NOT EXISTS `illama_keys` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `plate` varchar(12) NOT NULL,
    `owner` varchar(60) NOT NULL,
    `has_key` int(1) DEFAULT 0,
    `locked` int(1) DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `plate_owner` (`plate`, `owner`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;