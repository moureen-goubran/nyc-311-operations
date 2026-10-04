-- 04_complaint_types.sql
-- Resolution KPIs for every complaint type with at least 500 requests in the month.
-- Same percentile method and 7-day cohort rule as 03_agency_performance.sql.

WITH base AS (
    SELECT * FROM clean WHERE dq_flag = 'ok'
),
eligible AS (
    SELECT complaint_type
    FROM base
    GROUP BY complaint_type
    HAVING COUNT(*) >= 500
),
resolved_ranked AS (
    SELECT
        b.complaint_type,
        b.hours_to_close,
        ROW_NUMBER() OVER (PARTITION BY b.complaint_type ORDER BY b.hours_to_close) AS rn,
        COUNT(*)     OVER (PARTITION BY b.complaint_type)                           AS cnt
    FROM base b
    JOIN eligible e USING (complaint_type)
    WHERE b.is_resolved = 1
),
percentiles AS (
    SELECT
        complaint_type,
        MIN(CASE WHEN rn >= 0.5 * cnt THEN hours_to_close END) AS median_hours,
        MIN(CASE WHEN rn >= 0.9 * cnt THEN hours_to_close END) AS p90_hours
    FROM resolved_ranked
    GROUP BY complaint_type
),
-- Agency that handles most of each complaint type (some types are shared)
lead_agency AS (
    SELECT complaint_type, agency
    FROM (
        SELECT
            complaint_type,
            agency,
            ROW_NUMBER() OVER (PARTITION BY complaint_type ORDER BY COUNT(*) DESC) AS r
        FROM base
        GROUP BY complaint_type, agency
    )
    WHERE r = 1
)
SELECT
    b.complaint_type,
    l.agency                                                         AS lead_agency,
    COUNT(*)                                                         AS requests,
    SUM(b.is_resolved = 0)                                           AS still_open,
    ROUND(p.median_hours, 1)                                         AS median_hours,
    ROUND(p.p90_hours, 1)                                            AS p90_hours,
    ROUND(100.0 * SUM(b.created_date < '2026-09-26' AND b.is_resolved = 1 AND b.hours_to_close <= 168)
                / NULLIF(SUM(b.created_date < '2026-09-26'), 0), 1)  AS closed_within_7d_pct
FROM base b
JOIN eligible    e USING (complaint_type)
JOIN percentiles p USING (complaint_type)
JOIN lead_agency l USING (complaint_type)
GROUP BY b.complaint_type
ORDER BY requests DESC;
