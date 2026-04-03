-- =============================================
-- ANALYSIS: Player Lifetime Value (LTV)
-- Business Question: What is a player worth to
-- us, and how should we allocate acquisition budget?
-- =============================================


-- -------------------------------------------------
-- 1. Player LTV by segment
-- The number the CFO and CMO care about most
-- -------------------------------------------------
SELECT
    p.segment,
    COUNT(DISTINCT p.player_id) AS players,
    ROUND(AVG(COALESCE(ltv.total_deposits, 0)), 2) AS avg_lifetime_deposits,
    ROUND(AVG(COALESCE(ltv.total_ggr, 0)), 2) AS avg_lifetime_ggr,
    ROUND(AVG(COALESCE(ltv.total_ggr, 0) - COALESCE(bonus.total_bonus_cost, 0)), 2) AS avg_net_revenue,
    ROUND(AVG(COALESCE(ltv.total_sessions, 0)), 1) AS avg_sessions,
    ROUND(AVG(julianday(p.last_login) - julianday(p.registration_date)), 1) AS avg_lifetime_days
FROM players p
LEFT JOIN (
    SELECT
        gs.player_id,
        SUM(gs.ggr) AS total_ggr,
        COUNT(*) AS total_sessions
    FROM game_sessions gs
    GROUP BY gs.player_id
) ltv ON p.player_id = ltv.player_id
LEFT JOIN (
    SELECT
        t.player_id,
        SUM(t.amount) AS total_deposits
    FROM transactions t
    WHERE t.type = 'Deposit'
    GROUP BY t.player_id
) ltv ON p.player_id = ltv.player_id  -- Note: rename alias if your DB complains
LEFT JOIN (
    SELECT player_id, SUM(bonus_cost) AS total_bonus_cost
    FROM bonus_campaigns
    GROUP BY player_id
) bonus ON p.player_id = bonus.player_id
GROUP BY p.segment
ORDER BY avg_net_revenue DESC;


-- -------------------------------------------------
-- 2. LTV by acquisition country
-- Where should marketing spend their budget?
-- -------------------------------------------------
SELECT
    p.country,
    COUNT(DISTINCT p.player_id) AS players,
    ROUND(AVG(COALESCE(ltv.total_ggr, 0)), 2) AS avg_ggr,
    ROUND(AVG(COALESCE(dep.total_deposits, 0)), 2) AS avg_deposits,
    ROUND(
        COUNT(DISTINCT CASE WHEN p.status = 'Active' THEN p.player_id END) * 100.0
        / COUNT(DISTINCT p.player_id), 1
    ) AS active_rate_pct,
    ROUND(AVG(COALESCE(ltv.total_ggr, 0)), 2)
        * (COUNT(DISTINCT CASE WHEN p.status = 'Active' THEN p.player_id END) * 1.0
        / COUNT(DISTINCT p.player_id)) AS weighted_value_score
FROM players p
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr
    FROM game_sessions GROUP BY player_id
) ltv ON p.player_id = ltv.player_id
LEFT JOIN (
    SELECT player_id, SUM(amount) AS total_deposits
    FROM transactions WHERE type = 'Deposit' GROUP BY player_id
) dep ON p.player_id = dep.player_id
GROUP BY p.country
ORDER BY weighted_value_score DESC;


-- -------------------------------------------------
-- 3. High-value players at risk of churning
-- The VIP team needs this list ASAP
-- -------------------------------------------------
SELECT
    p.player_id,
    p.segment,
    p.country,
    p.preferred_game,
    CAST(julianday('2024-12-31') - julianday(p.last_login) AS INTEGER) AS days_since_login,
    ROUND(COALESCE(ltv.total_ggr, 0), 2) AS lifetime_ggr,
    ROUND(COALESCE(dep.total_deposits, 0), 2) AS lifetime_deposits,
    ltv.total_sessions
FROM players p
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr, COUNT(*) AS total_sessions
    FROM game_sessions GROUP BY player_id
) ltv ON p.player_id = ltv.player_id
LEFT JOIN (
    SELECT player_id, SUM(amount) AS total_deposits
    FROM transactions WHERE type = 'Deposit' GROUP BY player_id
) dep ON p.player_id = dep.player_id
WHERE p.segment IN ('VIP', 'Whale')
    AND julianday('2024-12-31') - julianday(p.last_login) BETWEEN 15 AND 45
    AND COALESCE(ltv.total_ggr, 0) > 500
ORDER BY ltv.total_ggr DESC
LIMIT 25;


-- -------------------------------------------------
-- 4. Executive KPI dashboard query
-- One query, all the numbers the CEO needs
-- -------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM players) AS total_players,
    (SELECT COUNT(*) FROM players WHERE status = 'Active') AS active_players,
    (SELECT ROUND(COUNT(CASE WHEN status = 'Active' THEN 1 END) * 100.0 / COUNT(*), 1) FROM players) AS active_pct,
    (SELECT ROUND(SUM(ggr), 2) FROM game_sessions) AS total_ggr,
    (SELECT ROUND(SUM(ggr), 2) FROM game_sessions WHERE session_date >= '2024-01-01') AS ggr_2024,
    (SELECT ROUND(SUM(amount), 2) FROM transactions WHERE type = 'Deposit') AS total_deposits,
    (SELECT ROUND(SUM(bonus_cost), 2) FROM bonus_campaigns) AS total_bonus_cost,
    (SELECT ROUND(SUM(ggr) - (SELECT SUM(bonus_cost) FROM bonus_campaigns), 2) FROM game_sessions) AS net_revenue,
    (SELECT COUNT(DISTINCT player_id) FROM game_sessions WHERE session_date >= '2024-12-01') AS mau_december;
