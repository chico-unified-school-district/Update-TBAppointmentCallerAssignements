SELECT DISTINCT date
 FROM {0}
WHERE
 del IS NULL
 AND date >= GETDATE();