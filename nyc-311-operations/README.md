# Who Waits on NYC 311?

An operations analysis of every NYC 311 service request opened in September 2026 (323,608 requests across 14 city agencies). It looks at how fast each agency closes requests, where the open backlog sits and how old it is, and whether boroughs really differ once you account for the mix of requests they send.

**[View the interactive dashboard](https://moureen-goubran.github.io/nyc-311-operations/dashboard/)**

## Key findings

1. **NYPD makes the city look fast.** NYPD handles 47% of requests (mostly parking and noise) and closes half within 1.4 hours. Without NYPD, the median time to close rises from 4.2 hours to 2.4 days, and the share closed within a week falls from 78% to 57%.
2. **Housing is where the backlog lives.** HPD receives 17.5% of requests but holds 35% of the open backlog (17,144 requests). Only 43% of HPD requests close within a week.
3. **Parks has the oldest queue.** DPR has 3,241 requests waiting 21+ days, more than any other agency. Only 10% of overgrown tree reports close within a week.
4. **Borough gaps are mostly mix.** Queens looks fastest overall, but 53% of its requests go to NYPD. Comparing only non-police requests, four boroughs land within 2.4 points of each other.
5. **Helicopter noise reports go unanswered in 311.** None of the 484 reports routed to EDC had been closed.

## Recommendations

- Report speed by agency against agency-specific targets instead of one citywide median.
- Run an oldest-first review of the ~5,900 HPD and Parks requests waiting 3+ weeks.
- Confirm who owns helicopter noise reports and how they are closed out.
- Align staffing with intake: weekday volume peaks late morning; weekend volume peaks around 10 p.m., when noise complaints are 58% of requests.

## Approach

| Step | What it does | File |
|---|---|---|
| Clean | Flags data anomalies and defines "resolved" without altering source rows | `sql/01_clean_view.sql` |
| Profile | Data-quality summary: duplicates, missing dates, impossible durations | `sql/02_data_quality.sql` |
| Agencies | Volume, median and 90th-percentile time to close, 7-day closure rate | `sql/03_agency_performance.sql` |
| Complaint types | Same KPIs for every complaint type with 500+ requests | `sql/04_complaint_types.sql` |
| Boroughs | Requests per 10,000 residents; closure rates with and without NYPD | `sql/05_borough.sql` |
| Daily volume | Requests per day with a 7-day moving average | `sql/06_daily_volume.sql` |
| Timing | Requests by weekday and hour | `sql/07_when_requests_arrive.sql` |
| Backlog aging | Open requests by agency and days waiting | `sql/08_backlog_aging.sql` |

SQL techniques used: CTEs, window functions (`ROW_NUMBER`, `RANK`, running and moving aggregates, `SUM() OVER ()` for shares), nearest-rank percentiles built from window functions (SQLite has no `PERCENTILE` function), and conditional aggregation.

### Analysis rules

- **Resolved** = status is `Closed` and the closed time is after the open time. "Closed" means the agency closed the ticket, which does not always mean the problem was fixed.
- **Anomalies:** 5,461 requests closed in the same second they opened and 211 "closed" before they opened (1.8% combined). They count toward volume but not toward time-to-close metrics.
- **7-day closure rate** only counts requests opened by Sep 25, so every request had at least seven full days to close before the data snapshot (Oct 3, 2026). Without this cut, late-month requests would make every agency look slower.
- **Backlog** is measured as September requests still unresolved at the snapshot. The extract contains only requests opened in September, so it cannot show closures of older requests.
- **Population** for per-capita rates comes from the 2020 U.S. Census.

## Run it yourself

Requires Python 3.9+ and pandas.

1. Download the data from NYC Open Data (dataset `erm2-nwe9`) with this query and save it as `data/311_sept2026.csv`:

   ```
   https://data.cityofnewyork.us/resource/erm2-nwe9.csv?$select=unique_key,created_date,closed_date,agency,complaint_type,borough,status&$where=created_date between '2026-09-01T00:00:00' and '2026-09-30T23:59:59'&$limit=1000000
   ```

   Results will differ slightly from mine depending on when you download, since open requests keep closing.

2. Run the analysis, then build the dashboard:

   ```
   pip install -r requirements.txt
   python run_analysis.py
   python dashboard/build_dashboard.py
   ```

Results land in `output/` as CSVs, and the dashboard is written to `dashboard/index.html`.

## Repository layout

```
├── run_analysis.py           # loads the CSV into SQLite and runs every query in /sql
├── sql/                      # one file per analysis step
├── output/                   # query results (CSV) and dashboard data (JSON)
├── dashboard/
│   ├── template.html         # dashboard layout and charts (no external libraries)
│   ├── build_dashboard.py    # injects the results into the template
│   └── index.html            # the built dashboard
└── data/                     # raw data (not committed; see "Run it yourself")
```

## About

Analysis by Moureen Goubran, Business Analyst. [LinkedIn](https://www.linkedin.com/in/moureen-goubran)

Data: City of New York, NYC Open Data. Population: U.S. Census Bureau.
