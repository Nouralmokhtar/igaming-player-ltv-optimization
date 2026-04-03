# Player Lifetime Value & Retention Optimization — iGaming Analytics

## Overview

This project analyzes **player behavior, retention, and revenue drivers** for a mid-size online casino operating across 10 markets. The goal was to move beyond surface-level reporting and deliver **actionable insights** that directly shaped product decisions, bonus strategy, and player segmentation.

### Business Context

The casino's leadership team needed answers to three critical questions:

1. **Which player segments drive the most revenue, and how do we retain them?**
2. **Are our bonus campaigns actually profitable, or are we burning cash?**
3. **Where in the player journey are we losing high-value players?**

---

## Key Findings & Recommendations

### Finding 1: The Whale Paradox
The top 5% of players (Whales) generate a disproportionate share of GGR — but they also have the highest churn risk after Day 30. 

**Recommendation:** Launch a dedicated VIP retention flow with personalized offers triggered at Day 25 (before the drop-off point, not after).

### Finding 2: Welcome Bonus Leak
Players who complete the welcome bonus wagering requirement are significantly more likely to remain active. But the majority of Casual-segment players never complete it — meaning we're paying bonus costs with no retention benefit.

**Recommendation:** Raise the minimum qualifying deposit and simplify wagering terms for low-value segments. Redirect saved budget to VIP/Whale retention campaigns with proven ROI.

### Finding 3: Cross-Game Players Retain 2x Better
Players who try 3+ game types in their first week retain at roughly double the rate of single-game players and generate higher lifetime GGR.

**Recommendation:** Add a "Try Live Casino" nudge during onboarding for slots-first players. A/B test a guided onboarding path that exposes new players to multiple game types.

---

## Project Structure

```
igaming-player-ltv-optimization/
│
├── README.md                          ← You are here
│
├── data/
│   ├── generate_data.py               ← Python script to create synthetic data
│   ├── players.csv                    ← 2,000 player profiles
│   ├── transactions.csv               ← Deposits & withdrawals
│   ├── game_sessions.csv              ← Detailed gameplay data with GGR
│   └── bonus_campaigns.csv            ← Bonus/promo tracking
│
├── sql/
│   ├── 01_schema.sql                  ← Table definitions & data loading
│   ├── 02_revenue_segmentation.sql    ← Revenue by segment, game, country
│   ├── 03_retention_churn.sql         ← Cohort retention & churn analysis
│   ├── 04_bonus_roi.sql              ← Bonus campaign ROI & abuse detection
│   └── 05_player_ltv.sql            ← Player LTV & executive dashboard
│
└── screenshots/                       ← Query result screenshots (optional)
```

## Data Description

| Table | Rows | Description |
|-------|------|-------------|
| `players` | 2,000 | Player profiles with segment, country, status, preferred game |
| `transactions` | ~25,000 | Every deposit and withdrawal with amounts and methods |
| `game_sessions` | ~45,000 | Individual play sessions with bets, wins, GGR, duration |
| `bonus_campaigns` | ~8,000 | Every bonus issued — type, amount, wagering status, cost |

**Note:** All data is synthetic, generated to mirror realistic iGaming distributions (segment weights, house edges, churn patterns). No real player data was used.

---

## How to Run

### Step 1: Generate the data
```bash
cd data/
python generate_data.py
```
This creates four CSV files in the `data/` folder.

### Step 2: Load into SQLite
```bash
cd data/
sqlite3 igaming.db < ../sql/01_schema.sql
```
Then in the SQLite shell:
```sql
.mode csv
.import --skip 1 players.csv players
.import --skip 1 transactions.csv transactions
.import --skip 1 game_sessions.csv game_sessions
.import --skip 1 bonus_campaigns.csv bonus_campaigns
```

### Step 3: Run the analysis queries
```bash
sqlite3 igaming.db < ../sql/02_revenue_segmentation.sql
sqlite3 igaming.db < ../sql/03_retention_churn.sql
sqlite3 igaming.db < ../sql/04_bonus_roi.sql
sqlite3 igaming.db < ../sql/05_player_ltv.sql
```

---

## SQL Techniques Used

- Common Table Expressions (CTEs) for cohort analysis
- Window functions (`PARTITION BY`) for within-group percentages
- Self-joins for comparing player behavior across time periods
- CASE statements for conditional aggregation
- Subqueries for KPI calculations
- Date arithmetic for retention and churn calculations

---

## Tools

- **SQL** (SQLite-compatible, easily portable to PostgreSQL/BigQuery)
- **Python** (data generation only — standard library, no external packages)

---

## About

This project was built to demonstrate how a **product-focused data analyst** approaches iGaming analytics — not just writing queries, but framing business questions, segmenting players meaningfully, and delivering insights that drive real decisions.

The analysis mirrors work I've done supporting Product, CRM, and executive stakeholders in the iGaming industry, covering player retention strategy, bonus optimization, and revenue analysis.
