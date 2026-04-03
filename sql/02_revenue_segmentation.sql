-- =============================================
-- ANALYSIS: Revenue & Player Segmentation
-- Business Question: Which player segments drive
-- the most revenue, and what does our player
-- base actually look like?
-- =============================================


-- -------------------------------------------------
-- 1. Revenue breakdown by player segment
-- This tells leadership where the money comes from
-- -------------------------------------------------
SELECT
    p.segment,
    COUNT(DISTINCT p.player_id) AS total_players,
    ROUND(COUNT(DISTINCT p.player_id) * 100.0 / (SELECT COUNT(*) FROM players), 1) AS pct_of_players,
    ROUND(SUM(gs.ggr), 2) AS total_ggr,
    ROUND(SUM(gs.ggr) * 100.0 / (SELECT SUM(ggr) FROM game_sessions), 1) AS pct_of_ggr,
    ROUND(SUM(gs.ggr) / COUNT(DISTINCT p.player_id), 2) AS ggr_per_player,
    ROUND(AVG(gs.total_bets), 2) AS avg_bet_per_session
FROM players p
JOIN game_sessions gs ON p.player_id = gs.player_id
GROUP BY p.segment
ORDER BY total_ggr DESC;


-- -------------------------------------------------
-- 2. Revenue by game type
-- Helps product team prioritize which games to invest in
-- -------------------------------------------------
SELECT
    gs.game_type,
    COUNT(DISTINCT gs.player_id) AS unique_players,
    COUNT(gs.session_id) AS total_sessions,
    ROUND(SUM(gs.ggr), 2) AS total_ggr,
    ROUND(AVG(gs.ggr), 2) AS avg_ggr_per_session,
    ROUND(SUM(gs.ggr) / COUNT(DISTINCT gs.player_id), 2) AS ggr_per_player,
    ROUND(AVG(gs.duration_minutes), 1) AS avg_session_length_min
FROM game_sessions gs
GROUP BY gs.game_type
ORDER BY total_ggr DESC;


-- -------------------------------------------------
-- 3. Revenue by country (top markets)
-- Shows which markets are worth doubling down on
-- -------------------------------------------------
SELECT
    p.country,
    COUNT(DISTINCT p.player_id) AS players,
    ROUND(SUM(gs.ggr), 2) AS total_ggr,
    ROUND(SUM(gs.ggr) / COUNT(DISTINCT p.player_id), 2) AS ggr_per_player,
    ROUND(SUM(CASE WHEN gs.game_type = 'Slots' THEN gs.ggr ELSE 0 END) * 100.0 / SUM(gs.ggr), 1) AS slots_ggr_pct,
    ROUND(SUM(CASE WHEN gs.game_type = 'Live Casino' THEN gs.ggr ELSE 0 END) * 100.0 / SUM(gs.ggr), 1) AS live_casino_ggr_pct
FROM players p
JOIN game_sessions gs ON p.player_id = gs.player_id
GROUP BY p.country
ORDER BY total_ggr DESC;


-- -------------------------------------------------
-- 4. Monthly revenue trend
-- Are we growing or declining? Seasonality?
-- -------------------------------------------------
SELECT
    strftime('%Y-%m', gs.session_date) AS month,
    COUNT(DISTINCT gs.player_id) AS active_players,
    ROUND(SUM(gs.ggr), 2) AS monthly_ggr,
    ROUND(SUM(gs.total_bets), 2) AS monthly_handle,
    ROUND(SUM(gs.ggr) / SUM(gs.total_bets) * 100, 2) AS hold_pct
FROM game_sessions gs
GROUP BY strftime('%Y-%m', gs.session_date)
ORDER BY month;


-- -------------------------------------------------
-- 5. Player status distribution by segment
-- How healthy is each segment?
-- -------------------------------------------------
SELECT
    p.segment,
    p.status,
    COUNT(*) AS player_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY p.segment), 1) AS pct_within_segment
FROM players p
GROUP BY p.segment, p.status
ORDER BY p.segment, player_count DESC;
