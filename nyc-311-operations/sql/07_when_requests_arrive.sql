-- 07_when_requests_arrive.sql
-- Request volume by day of week and hour of day (for staffing decisions).

SELECT
    dow,
    hour_of_day,
    COUNT(*) AS requests
FROM clean
GROUP BY dow, hour_of_day
ORDER BY dow, hour_of_day;
