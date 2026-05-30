const express = require('express');
const db = require('../db');

const router = express.Router();

router.get('/:userId', async (req, res) => {
  const { userId } = req.params;
  if (!userId) {
    return res.status(400).json({ error: 'userId is required' });
  }

  try {
    const [rows] = await db.query(
      `SELECT
          notificationId AS id,
          notificationId AS notificationId,
          type,
          title,
          body AS message,
          isRead,
          createdAt,
          relatedRequestId
       FROM usernotification
       WHERE userId = ?
       ORDER BY createdAt DESC
       LIMIT 200`,
      [userId],
    );
    res.json(rows);
  } catch (err) {
    if (err && err.code === 'ER_NO_SUCH_TABLE') {
      return res.json([]);
    }
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
