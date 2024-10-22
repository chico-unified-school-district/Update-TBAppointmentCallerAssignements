DECLARE
 @date date = '{1}'
SELECT DISTINCT date,caller1 as caller
FROM {0}
WHERE
    date = @date
    AND del IS NULL
    AND caller1 <> ''
    AND caller1 IS NOT NULL
UNION
SELECT DISTINCT date,caller2 as caller
FROM {0}
WHERE
    date = @date
    AND del IS NULL
    AND caller2 <> ''
    AND caller2 IS NOT NULL
UNION
SELECT DISTINCT date,caller3 as caller
FROM {0}
WHERE
    date = @date
    AND del IS NULL
    AND caller3 <> ''
    AND caller3 IS NOT NULL