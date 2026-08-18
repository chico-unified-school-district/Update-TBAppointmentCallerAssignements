SELECT id,date FROM {0}
WHERE
 date = @date
 AND del IS NULL
 AND (nurseName IS NULL OR nurseName = '');