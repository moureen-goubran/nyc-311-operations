-- 03_agency_performance.sql
-- Resolution KPIs by agency.
--
-- Median and 90th-percentile hours use the nearest-rank method, built with
-- window functions because SQLite has no PERCENTILE function.
--
-- The 7-day closure rate only counts requests opened on or before Sep 25, so every
-- request in the cohort had at least 7 full days to close before the data snapshot
-- (early Oct 3). Without this cut, late-September requests would drag the rate down
-- simply because they had not had time to close yet.

WITH base AS (
    SELECT * FROM clean WHERE dq_flag = 'ok'
),
resolved_ranked AS (
    SELECT
        agency,
        hours_to_close,
        ROW_NUMBER() OVER (PARTITION BY agency ORDER BY hours_to_close) AS rn,
        COUNT(*)     OVER (PARTITION BY agency)                         AS cnt
    FROM base
    WHERE is_resolved = 1
),
percentiles AS (
    SELECT
        agency,
        MIN(CASE WHEN rn >= 0.5 * cnt THEN hours_to_close END) AS median_hours,
        MIN(CASE WHEN rn >= 0.9 * cnt THEN hours_to_close END) AS p90_hours
    FROM resolved_ranked
    GROUP BY agency
),
cohort AS (
    SELECT
        agency,
        COUNT(*)                                                         AS cohort_n,
        SUM(is_resolved = 1 AND hours_to_close <= 24 * 7)                AS closed_7d
    FROM base
    WHERE created_date < '2026-09-26'
    GROUP BY agency
),
volume AS (
    SELECT
        agency,
        COUNT(*)                                   AS requests,
        SUM(is_resolved)                           AS resolved,
        SUM(is_resolved = 0)                       AS still_open
    FROM base
    GROUP BY agency
)
SELECT
    v.agency,
    v.requests,
    ROUND(100.0 * v.requests / SUM(v.requests) OVER (), 1)  AS share_of_volume_pct,
    v.still_open,
    ROUND(p.median_hours, 1)                                AS median_hours,
    ROUND(p.p90_hours, 1)                                   AS p90_hours,
    c.cohort_n,
    ROUND(100.0 * c.closed_7d / c.cohort_n, 1)              AS closed_within_7d_pct,
    RANK() OVER (ORDER BY v.still_open DESC)                AS backlog_rank
FROM volume v
LEFT JOIN percentiles p USING (agency)
LEFT JOIN cohort      c USING (agency)
ORDER BY v.requests DESC;
