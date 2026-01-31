CREATE DATABASE IF NOT EXISTS `hello-world`;
USE `hello-world`;

CREATE TABLE IF NOT EXISTS user (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL
);

INSERT INTO user (name) VALUES ("hello"), ("world");
