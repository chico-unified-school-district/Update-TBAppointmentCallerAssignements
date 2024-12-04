DECLARE
@myDate date = '{1}'
SELECT id,date,nurseName as caller
FROM {0}
WHERE
 date = @myDate
 AND del IS NULL
 AND (nurseName IS NULL OR nurseName = '');