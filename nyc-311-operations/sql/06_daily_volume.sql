-- 06_daily_volume.sql
-- Requests opened per day with a trailing 7-day average.
--
-- Note: this extract only contains requests OPENED in September, so it cannot
-- measure a true daily backlog (closures of August requests are not in the data).
-- The real backlog view is 08_backlog_aging.sql.

SELECT
    created_day                                                   AS day,
    CASE dow WHEN 0 THEN 'Sun' WHEN 1 THEN 'Mon' WHEN 2 THEN 'Tue' WHEN 3 THEN 'Wed'
             WHEN 4 THEN 'Thu' WHEN 5 THEN 'Fri' ELSE 'Sat' END    AS weekday,
    COUNT(*)                                                      AS opened,
    ROUND(AVG(COUNT(*)) OVER (ORDER BY created_day
                              ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS opened_7day_avg
FROM clean
WHERE dq_flag = 'ok'
GROUP BY created_day, dow
ORDER BY created_day;
