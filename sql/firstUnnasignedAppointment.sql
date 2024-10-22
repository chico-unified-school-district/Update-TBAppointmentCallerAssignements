SELECT TOP 1 id,date
FROM {0}
WHERE
date = '{1}'
AND del IS NULL
AND (nurseName IS NULL OR nurseName = '');