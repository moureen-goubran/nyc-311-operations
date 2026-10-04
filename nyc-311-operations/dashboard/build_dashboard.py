"""
Builds dashboard/index.html from the analysis outputs.
Run run_analysis.py first, then:  python dashboard/build_dashboard.py
"""
import json
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "output"
HERE = Path(__file__).resolve().parent

AGENCY_NAMES = {
    "NYPD": "Police Department",
    "HPD": "Housing Preservation & Development",
    "DSNY": "Sanitation",
    "DOT": "Transportation",
    "DPR": "Parks & Recreation",
    "DEP": "Environmental Protection",
    "DOHMH": "Health & Mental Hygiene",
    "DOB": "Buildings",
    "DHS": "Homeless Services",
    "TLC": "Taxi & Limousine Commission",
    "DCWP": "Consumer & Worker Protection",
    "EDC": "Economic Development Corp.",
    "OOS": "Office of the Sheriff",
    "OTI": "Technology & Innovation",
}


def clean(v):
    return None if pd.isna(v) else v


def main() -> None:
    data = json.loads((OUT / "dashboard_data.json").read_text())

    aging = pd.read_csv(OUT / "backlog_aging.csv").set_index("agency")
    agencies = []
    for row in pd.read_csv(OUT / "agency_performance.csv").to_dict(orient="records"):
        a = row["agency"]
        ag = aging.loc[a] if a in aging.index else None
        agencies.append({
            "code": a,
            "name": AGENCY_NAMES.get(a, a),
            "requests": int(row["requests"]),
            "share": row["share_of_volume_pct"],
            "open": int(row["still_open"]),
            "median_h": clean(row["median_hours"]),
            "p90_h": clean(row["p90_hours"]),
            "closed7": row["closed_within_7d_pct"],
            "aging": [int(ag[c]) for c in ["age_under_7d", "age_7_to_14d", "age_14_to_21d", "age_21d_plus"]]
            if ag is not None else [0, 0, 0, 0],
        })

    ct = pd.read_csv(OUT / "complaint_types.csv")
    slow = (
        ct[ct.requests >= 1000]
        .sort_values("closed_within_7d_pct")
        .head(10)
    )
    complaints = [
        {
            "type": r.complaint_type.title() if r.complaint_type.isupper() else r.complaint_type,
            "agency": r.lead_agency,
            "requests": int(r.requests),
            "open": int(r.still_open),
            "median_h": r.median_hours,
            "closed7": r.closed_within_7d_pct,
        }
        for r in slow.itertuples()
    ]

    daily = pd.read_csv(OUT / "daily_volume.csv")
    # Average per calendar day, since September 2026 has five Tuesdays and Wednesdays
    days_per_dow = daily.weekday.value_counts().to_dict()
    dow_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    w = pd.read_csv(OUT / "when_requests_arrive.csv")
    heat = [[0] * 24 for _ in range(7)]
    for r in w.itertuples():
        heat[r.dow][r.hour_of_day] = round(r.requests / days_per_dow[dow_names[r.dow]])

    payload = {
        "kpis": data["kpis"],
        "quality": data["data_quality"][0],
        "agencies": agencies,
        "complaints": complaints,
        "boroughs": data["borough"],
        "daily": daily[["day", "weekday", "opened", "opened_7day_avg"]].to_dict(orient="records"),
        "heat": heat,
    }

    html = (HERE / "template.html").read_text()
    html = html.replace("/*__DATA__*/null", json.dumps(payload, separators=(",", ":")))
    (HERE / "index.html").write_text(html)
    print("wrote", HERE / "index.html", f"({len(html)/1024:.0f} KB)")


if __name__ == "__main__":
    main()
