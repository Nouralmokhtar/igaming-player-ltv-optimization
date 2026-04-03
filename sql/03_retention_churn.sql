-- =============================================
-- ANALYSIS: Player Retention & Churn
-- Business Question: Where and why are we
-- losing players? Which cohorts retain best?
-- =============================================


-- -------------------------------------------------
-- 1. Monthly registration cohort retention
-- The classic cohort analysis — shows how many
-- players from each signup month are still active
-- in the following months
-- -------------------------------------------------
WITH player_cohort AS (
    SELECT
        player_id,
        strftime('%Y-%m', registration_date) AS cohort_month
    FROM players
),
monthly_activity AS (
    SELECT
        gs.player_id,
        strftime('%Y-%m', gs.session_date) AS activity_month
    FROM game_sessions gs
    GROUP BY gs.player_id, strftime('%Y-%m', gs.session_date)
)
SELECT
    pc.cohort_month,
    COUNT(DISTINCT pc.player_id) AS cohort_size,
    -- Month 0 = registration month, Month 1 = next month, etc.
    COUNT(DISTINCT CASE
        WHEN ma.activity_month = pc.cohort_month THEN ma.player_id
    END) AS month_0,
    COUNT(DISTINCT CASE
        WHEN strftime('%Y-%m', date(pc.cohort_month || '-01', '+1 month')) = ma.activity_month
        THEN ma.player_id
    END) AS month_1,
    COUNT(DISTINCT CASE
        WHEN strftime('%Y-%m', date(pc.cohort_month || '-01', '+2 month')) = ma.activity_month
        THEN ma.player_id
    END) AS month_2,
    COUNT(DISTINCT CASE
        WHEN strftime('%Y-%m', date(pc.cohort_month || '-01', '+3 month')) = ma.activity_month
        THEN ma.player_id
    END) AS month_3,
    COUNT(DISTINCT CASE
        WHEN strftime('%Y-%m', date(pc.cohort_month || '-01', '+6 month')) = ma.activity_month
        THEN ma.player_id
    END) AS month_6
FROM player_cohort pc
LEFT JOIN monthly_activity ma ON pc.player_id = ma.player_id
GROUP BY pc.cohort_month
ORDER BY pc.cohort_month;


-- -------------------------------------------------
-- 2. Churn analysis — who stopped playing and when
-- A player is "churned" if they haven't played
-- in the last 30 days from end of dataset
-- -------------------------------------------------
SELECT
    p.segment,
    p.country,
    p.preferred_game,
    COUNT(*) AS churned_players,
    ROUND(AVG(julianday('2024-12-31') - julianday(p.last_login)), 1) AS avg_days_since_login,
    ROUND(AVG(total_deposits.deposit_total), 2) AS avg_lifetime_deposits
FROM players p
LEFT JOIN (
    SELECT player_id, SUM(amount) AS deposit_total
    FROM transactions
    WHERE type = 'Deposit'
    GROUP BY player_id
) total_deposits ON p.player_id = total_deposits.player_id
WHERE julianday('2024-12-31') - julianday(p.last_login) > 30
GROUP BY p.segment, p.country, p.preferred_game
HAVING COUNT(*) >= 5
ORDER BY churned_players DESC
LIMIT 20;


-- -------------------------------------------------
-- 3. Days to churn by segment
-- How long does each segment stay before leaving?
-- This helps CRM know WHEN to intervene
-- -------------------------------------------------
SELECT
    p.segment,
    ROUND(AVG(julianday(p.last_login) - julianday(p.registration_date)), 1) AS avg_active_days,
    ROUND(MIN(julianday(p.last_login) - julianday(p.registration_date)), 1) AS min_active_days,
    ROUND(MAX(julianday(p.last_login) - julianday(p.registration_date)), 1) AS max_active_days,
    COUNT(*) AS total_players
FROM players p
WHERE p.status IN ('Inactive', 'Dormant')
GROUP BY p.segment
ORDER BY avg_active_days DESC;


-- -------------------------------------------------
-- 4. First-week behavior and retention
-- Players who do X in week 1 retain better
-- This is gold for product team onboarding decisions
-- -------------------------------------------------
WITH first_week_activity AS (
    SELECT
        gs.player_id,
        COUNT(DISTINCT gs.game_type) AS games_tried,
        SUM(gs.total_bets) AS first_week_bets,
        COUNT(gs.session_id) AS first_week_sessions,
        MAX(CASE WHEN gs.game_type = 'Live Casino' THEN 1 ELSE 0 END) AS tried_live_casino
    FROM game_sessions gs
    JOIN players p ON gs.player_id = p.player_id
    WHERE julianday(gs.session_date) - julianday(p.registration_date) <= 7
    GROUP BY gs.player_id
)
SELECT
    CASE
        WHEN fwa.games_tried >= 3 THEN '3+ games tried'
        WHEN fwa.games_tried = 2 THEN '2 games tried'
        ELSE '1 game only'
    END AS first_week_behavior,
    COUNT(*) AS players,
    ROUND(
        COUNT(CASE WHEN p.status = 'Active' THEN 1 END) * 100.0 / COUNT(*), 1
    ) AS retention_rate_pct,
    ROUND(AVG(lifetime.total_ggr), 2) AS avg_lifetime_ggr
FROM first_week_activity fwa
JOIN players p ON fwa.player_id = p.player_id
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr
    FROM game_sessions
    GROUP BY player_id
) lifetime ON fwa.player_id = lifetime.player_id
GROUP BY first_week_behavior
ORDER BY retention_rate_pct DESC;


-- -------------------------------------------------
-- 5. Cross-game migration and its impact
-- Players who try multiple game types — do they
-- retain and spend more?
-- -------------------------------------------------
WITH player_game_diversity AS (
    SELECT
        player_id,
        COUNT(DISTINCT game_type) AS game_types_played
    FROM game_sessions
    GROUP BY player_id
)
SELECT
    pgd.game_types_played,
    COUNT(DISTINCT pgd.player_id) AS player_count,
    ROUND(
        COUNT(DISTINCT CASE WHEN p.status = 'Active' THEN p.player_id END) * 100.0
        / COUNT(DISTINCT pgd.player_id), 1
    ) AS active_rate_pct,
    ROUND(AVG(lifetime.total_ggr), 2) AS avg_lifetime_ggr,
    ROUND(AVG(lifetime.total_sessions), 1) AS avg_sessions
FROM player_game_diversity pgd
JOIN players p ON pgd.player_id = p.player_id
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr, COUNT(*) AS total_sessions
    FROM game_sessions
    GROUP BY player_id
) lifetime ON pgd.player_id = lifetime.player_id
GROUP BY pgd.game_types_played
ORDER BY pgd.game_types_played;
