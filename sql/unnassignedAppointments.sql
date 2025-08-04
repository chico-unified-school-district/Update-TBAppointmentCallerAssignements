SELECT id,date,nurseName as caller
FROM {0}
WHERE
 date = @date
 AND del IS NULL
 AND (nurseName IS NULL OR nurseName = '');