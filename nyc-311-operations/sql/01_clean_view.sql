-- 01_clean_view.sql
-- Adds analysis flags to the raw 311 extract without altering the source rows.
--
-- Rules (documented in README):
--   * A request is RESOLVED when status = 'Closed' AND closed_date is after created_date.
--   * Requests closed at the exact second they were opened (zero duration) or
--     "closed" before they were opened (negative duration) are data anomalies.
--     They stay in volume counts but are excluded from resolution metrics.
--   * Requests not marked Closed are treated as unresolved, even if a closed_date exists.

DROP VIEW IF EXISTS clean;

CREATE VIEW clean AS
SELECT
    unique_key,
    created_date,
    closed_date,
    agency,
    complaint_type,
    borough,
    status,
    julianday(created_date)                                        AS created_jd,
    julianday(closed_date)                                         AS closed_jd,
    (julianday(closed_date) - julianday(created_date)) * 24.0      AS hours_to_close,
    CASE
        WHEN closed_date IS NOT NULL AND closed_date <  created_date THEN 'negative_duration'
        WHEN closed_date IS NOT NULL AND closed_date =  created_date THEN 'zero_duration'
        ELSE 'ok'
    END                                                            AS dq_flag,
    CASE
        WHEN status = 'Closed' AND closed_date > created_date THEN 1 ELSE 0
    END                                                            AS is_resolved,
    CAST(strftime('%w', created_date) AS INTEGER)                  AS dow,   -- 0 = Sunday
    CAST(strftime('%H', created_date) AS INTEGER)                  AS hour_of_day,
    substr(created_date, 1, 10)                                    AS created_day
FROM requests;
