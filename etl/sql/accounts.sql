/* =========================================================
   accounts -> filtered extract
   - keep only users with last_login NOT NULL
   - keep only emails starting with CH, DE, GR, IT
   - extract country prefix from email
========================================================= */

SELECT
    id,
    email,
    last_login,
    SUBSTRING(email, 1, 2) AS country
FROM accounts
WHERE last_login IS NOT NULL
  AND email REGEXP '^(CH|DE|GR|IT)';