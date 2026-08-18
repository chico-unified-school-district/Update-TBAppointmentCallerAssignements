SELECT id,date,nurseName FROM {0}
WHERE del IS NULL AND date >= DATEADD(day,-1,GETDATE())
ORDER BY date ASC;