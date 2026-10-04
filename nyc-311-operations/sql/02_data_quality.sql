-- 02_data_quality.sql
-- Profiles the extract so every downstream number can be traced back to a rule.

SELECT
    COUNT(*)                                                      AS total_requests,
    COUNT(DISTINCT unique_key)                                    AS distinct_keys,
    SUM(closed_date IS NULL)                                      AS missing_closed_date,
    SUM(dq_flag = 'negative_duration')                            AS negative_duration,
    SUM(dq_flag = 'zero_duration')                                AS zero_duration,
    SUM(status <> 'Closed' AND closed_date IS NOT NULL)           AS not_closed_but_has_date,
    SUM(borough = 'Unspecified')                                  AS unspecified_borough,
    MIN(created_date)                                             AS first_created,
    MAX(created_date)                                             AS last_created,
    MAX(closed_date)                                              AS snapshot_time
FROM clean;
