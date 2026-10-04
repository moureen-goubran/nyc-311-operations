-- 05_borough.sql
-- Volume per 10,000 residents and resolution KPIs by borough.
-- Population: 2020 U.S. Census (borough_population table, loaded by run_analysis.py).
-- Requests with borough = 'Unspecified' are excluded here (they are under 0.2% of volume).

WITH base AS (
    SELECT * FROM clean WHERE dq_flag = 'ok' AND borough <> 'Unspecified'
),
resolved_ranked AS (
    SELECT
        borough,
        hours_to_close,
        ROW_NUMBER() OVER (PARTITION BY borough ORDER BY hours_to_close) AS rn,
        COUNT(*)     OVER (PARTITION BY borough)                         AS cnt
    FROM base
    WHERE is_resolved = 1
),
percentiles AS (
    SELECT
        borough,
        MIN(CASE WHEN rn >= 0.5 * cnt THEN hours_to_close END) AS median_hours
    FROM resolved_ranked
    GROUP BY borough
)
SELECT
    b.borough,
    COUNT(*)                                                         AS requests,
    pop.population,
    ROUND(10000.0 * COUNT(*) / pop.population, 1)                    AS requests_per_10k,
    SUM(b.is_resolved = 0)                                           AS still_open,
    ROUND(p.median_hours, 1)                                         AS median_hours,
    ROUND(100.0 * SUM(b.created_date < '2026-09-26' AND b.is_resolved = 1 AND b.hours_to_close <= 168)
                / SUM(b.created_date < '2026-09-26'), 1)             AS closed_within_7d_pct,
    -- Same rate without NYPD, so boroughs with more parking/noise calls don't look faster
    ROUND(100.0 * SUM(b.agency <> 'NYPD' AND b.created_date < '2026-09-26' AND b.is_resolved = 1 AND b.hours_to_close <= 168)
                / SUM(b.agency <> 'NYPD' AND b.created_date < '2026-09-26'), 1) AS closed_within_7d_excl_nypd_pct,
    ROUND(100.0 * SUM(b.agency = 'NYPD') / COUNT(*), 1)              AS nypd_share_pct
FROM base b
JOIN borough_population pop USING (borough)
JOIN percentiles        p   USING (borough)
GROUP BY b.borough
ORDER BY requests_per_10k DESC;
