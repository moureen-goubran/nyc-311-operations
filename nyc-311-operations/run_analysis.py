"""
NYC 311 Operations Analysis - September 2026
Loads the raw extract into SQLite, runs every query in /sql in order,
and writes each result to /output as CSV plus one JSON file for the dashboard.

Usage:  python run_analysis.py
Requires: Python 3.9+, pandas
"""
import json
import sqlite3
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).parent
RAW = ROOT / "data" / "311_sept2026.csv"
SQL_DIR = ROOT / "sql"
OUT = ROOT / "output"
OUT.mkdir(exist_ok=True)

# 2020 U.S. Census, NYC borough populations
BOROUGH_POPULATION = {
    "BROOKLYN": 2_736_074,
    "QUEENS": 2_405_464,
    "MANHATTAN": 1_694_251,
    "BRONX": 1_472_654,
    "STATEN ISLAND": 495_747,
}


def load(con: sqlite3.Connection) -> None:
    df = pd.read_csv(RAW, dtype=str)
    df.to_sql("requests", con, if_exists="replace", index=False)
    pd.DataFrame(
        BOROUGH_POPULATION.items(), columns=["borough", "population"]
    ).to_sql("borough_population", con, if_exists="replace", index=False)


def main() -> None:
    con = sqlite3.connect(":memory:")
    load(con)

    results = {}
    for path in sorted(SQL_DIR.glob("*.sql")):
        sql = path.read_text()
        if path.name.startswith("01_"):
            con.executescript(sql)
            continue
        df = pd.read_sql(sql, con)
        name = path.stem.split("_", 1)[1]
        df.to_csv(OUT / f"{name}.csv", index=False)
        results[name] = df.to_dict(orient="records")
        print(f"{path.name}: {len(df)} rows")

    # Headline KPIs (same rules as the SQL files)
    k = pd.read_sql(
        """
        SELECT
            COUNT(*)                                                         AS requests,
            SUM(is_resolved)                                                 AS resolved,
            SUM(is_resolved = 0)                                             AS still_open,
            ROUND(100.0 * SUM(created_date < '2026-09-26' AND is_resolved = 1 AND hours_to_close <= 168)
                        / SUM(created_date < '2026-09-26'), 1)               AS closed_within_7d_pct,
            ROUND(100.0 * SUM(is_resolved = 1 AND hours_to_close <= 24) / COUNT(*), 1) AS closed_within_24h_pct
        FROM clean WHERE dq_flag = 'ok'
        """,
        con,
    ).iloc[0].to_dict()
    med = pd.read_sql(
        "SELECT hours_to_close FROM clean WHERE dq_flag='ok' AND is_resolved=1", con
    )["hours_to_close"]
    k["median_hours"] = round(float(med.quantile(0.5, interpolation="higher")), 1)

    # Same KPIs without NYPD, which is ~47% of volume and closes most tickets within hours
    nn = pd.read_sql(
        """
        SELECT
            ROUND(100.0 * SUM(created_date < '2026-09-26' AND is_resolved = 1 AND hours_to_close <= 168)
                        / SUM(created_date < '2026-09-26'), 1) AS closed_within_7d_pct
        FROM clean WHERE dq_flag = 'ok' AND agency <> 'NYPD'
        """,
        con,
    ).iloc[0]
    nn_med = pd.read_sql(
        "SELECT hours_to_close FROM clean WHERE dq_flag='ok' AND is_resolved=1 AND agency<>'NYPD'", con
    )["hours_to_close"]
    k["excl_nypd_closed_within_7d_pct"] = float(nn["closed_within_7d_pct"])
    k["excl_nypd_median_hours"] = round(float(nn_med.quantile(0.5, interpolation="higher")), 1)
    results["kpis"] = k

    (OUT / "dashboard_data.json").write_text(json.dumps(results, indent=1, default=str))
    print("KPIs:", k)


if __name__ == "__main__":
    main()
