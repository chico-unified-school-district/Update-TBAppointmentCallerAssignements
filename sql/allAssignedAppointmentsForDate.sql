SELECT id, nurseName as caller
FROM {0}
WHERE
date = @date
AND ( nurseName IS NOT NULL OR nurseName <> '')
AND del IS NULL;
