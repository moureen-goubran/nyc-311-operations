-- 08_backlog_aging.sql
-- The real backlog: September requests still unresolved at the data snapshot,
-- bucketed by how long they have been waiting. Age is measured against the
-- snapshot time (latest closed_date in the extract).

WITH snap AS (
    SELECT julianday(MAX(closed_date)) AS snap_jd FROM clean
),
open_items AS (
    SELECT
        c.agency,
        (s.snap_jd - c.created_jd) AS age_days
    FROM clean c CROSS JOIN snap s
    WHERE c.dq_flag = 'ok' AND c.is_resolved = 0
)
SELECT
    agency,
    COUNT(*)                                          AS open_requests,
    SUM(age_days <  7)                                AS age_under_7d,
    SUM(age_days >= 7  AND age_days < 14)             AS age_7_to_14d,
    SUM(age_days >= 14 AND age_days < 21)             AS age_14_to_21d,
    SUM(age_days >= 21)                               AS age_21d_plus,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_of_backlog_pct
FROM open_items
GROUP BY agency
ORDER BY open_requests DESC;
