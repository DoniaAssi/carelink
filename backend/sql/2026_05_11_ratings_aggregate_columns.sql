-- Aggregate rating count on careprovider + optional updatedAt on providervisitrating.
-- Run on your MySQL CareLink database once. If a column already exists, skip that statement.

ALTER TABLE careprovider
  ADD COLUMN ratingsCount INT NOT NULL DEFAULT 0;

ALTER TABLE providervisitrating
  ADD COLUMN updatedAt TIMESTAMP NULL DEFAULT NULL
    ON UPDATE CURRENT_TIMESTAMP
    AFTER createdAt;

-- Backfill ratingsCount from existing visit ratings (safe to re-run logic via app recompute too).
UPDATE careprovider c
SET c.ratingsCount = (
  SELECT COUNT(*) FROM providervisitrating p WHERE p.providerUserId = c.userId
),
c.overallRating = COALESCE(
  (SELECT ROUND(AVG(p.stars), 2) FROM providervisitrating p WHERE p.providerUserId = c.userId),
  0
);
