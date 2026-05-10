CREATE TABLE IF NOT EXISTS message (
  messageId VARCHAR(64) NOT NULL,
  senderId VARCHAR(64) NOT NULL,
  receiverId VARCHAR(64) NOT NULL,
  message TEXT NOT NULL,
  createdAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (messageId),
  KEY idx_message_sender_receiver_created (senderId, receiverId, createdAt),
  KEY idx_message_receiver_sender_created (receiverId, senderId, createdAt)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
