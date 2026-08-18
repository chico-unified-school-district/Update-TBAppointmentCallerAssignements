SELECT date,caller1,caller2,caller3
 FROM {0}
WHERE
-- Ensure that at least one caller slot has valid data
 (
  (caller1 IS NOT NULL AND caller1 <> '') OR
  (caller2 IS NOT NULL AND caller2 <> '') OR
  (caller3 IS NOT NULL AND caller3 <> '')
 )
 AND del IS NULL
 AND date >= DATEADD(day,-1,GETDATE())
 -- AND date = '2026-09-02'
ORDER BY date ASC;