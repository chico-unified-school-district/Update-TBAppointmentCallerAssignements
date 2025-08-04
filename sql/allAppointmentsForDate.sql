SELECT id, nurseName as caller
FROM {0}
WHERE
date = @date
AND del IS NULL;
