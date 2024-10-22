DECLARE
@myDate date = '{1}'
SELECT id,date
FROM {0}
WHERE
 date = @myDate
 AND del IS NULL
 AND (nurseName IS NULL OR nurseName = '');