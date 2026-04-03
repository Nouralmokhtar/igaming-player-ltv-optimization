-- =============================================
-- ANALYSIS: Bonus Campaign ROI
-- Business Question: Are our bonuses actually
-- making us money, or are we giving away margin?
-- =============================================


-- -------------------------------------------------
-- 1. Overall bonus ROI by type
-- For each bonus type: what did we spend vs what
-- GGR did those players generate?
-- -------------------------------------------------
SELECT
    bc.bonus_type,
    COUNT(*) AS times_given,
    COUNT(DISTINCT bc.player_id) AS unique_players,
    ROUND(SUM(bc.bonus_amount), 2) AS total_bonus_given,
    ROUND(SUM(bc.bonus_cost), 2) AS total_bonus_cost,
    ROUND(AVG(CASE WHEN bc.wagering_met = 'Yes' THEN 1.0 ELSE 0.0 END) * 100, 1) AS wagering_completion_pct,
    ROUND(SUM(player_ggr.ggr_after_bonus), 2) AS ggr_after_bonus,
    ROUND(
        (SUM(player_ggr.ggr_after_bonus) - SUM(bc.bonus_cost))
        / NULLIF(SUM(bc.bonus_cost), 0), 2
    ) AS roi
FROM bonus_campaigns bc
LEFT JOIN (
    -- GGR generated within 30 days after receiving the bonus
    SELECT
        bc2.bonus_id,
        COALESCE(SUM(gs.ggr), 0) AS ggr_after_bonus
    FROM bonus_campaigns bc2
    LEFT JOIN game_sessions gs
        ON bc2.player_id = gs.player_id
        AND gs.session_date >= bc2.bonus_date
        AND gs.session_date <= date(bc2.bonus_date, '+30 days')
    GROUP BY bc2.bonus_id
) player_ggr ON bc.bonus_id = player_ggr.bonus_id
GROUP BY bc.bonus_type
ORDER BY roi DESC;


-- -------------------------------------------------
-- 2. Bonus ROI by player segment
-- Are we spending bonus budget on the right players?
-- -------------------------------------------------
SELECT
    p.segment,
    COUNT(bc.bonus_id) AS bonuses_given,
    ROUND(SUM(bc.bonus_amount), 2) AS total_bonus_value,
    ROUND(SUM(bc.bonus_cost), 2) AS total_cost,
    ROUND(SUM(bc.bonus_cost) / COUNT(DISTINCT bc.player_id), 2) AS cost_per_player,
    ROUND(AVG(CASE WHEN bc.wagering_met = 'Yes' THEN 1.0 ELSE 0.0 END) * 100, 1) AS completion_rate,
    ROUND(
        SUM(lifetime.total_ggr) / NULLIF(SUM(bc.bonus_cost), 0), 2
    ) AS ggr_to_bonus_ratio
FROM bonus_campaigns bc
JOIN players p ON bc.player_id = p.player_id
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr
    FROM game_sessions
    GROUP BY player_id
) lifetime ON bc.player_id = lifetime.player_id
GROUP BY p.segment
ORDER BY ggr_to_bonus_ratio DESC;


-- -------------------------------------------------
-- 3. Welcome bonus effectiveness
-- Does the welcome bonus actually convert players
-- into long-term depositors?
-- -------------------------------------------------
WITH welcome_bonus_players AS (
    SELECT
        bc.player_id,
        bc.bonus_amount,
        bc.wagering_met,
        p.segment,
        p.status
    FROM bonus_campaigns bc
    JOIN players p ON bc.player_id = p.player_id
    WHERE bc.bonus_type = 'Welcome Bonus'
)
SELECT
    wb.wagering_met AS completed_wagering,
    COUNT(*) AS players,
    ROUND(COUNT(CASE WHEN wb.status = 'Active' THEN 1 END) * 100.0 / COUNT(*), 1) AS still_active_pct,
    ROUND(AVG(deposits.deposit_count), 1) AS avg_deposits_after,
    ROUND(AVG(deposits.total_deposited), 2) AS avg_total_deposited
FROM welcome_bonus_players wb
LEFT JOIN (
    SELECT
        t.player_id,
        COUNT(*) AS deposit_count,
        SUM(t.amount) AS total_deposited
    FROM transactions t
    JOIN bonus_campaigns bc ON t.player_id = bc.player_id
        AND bc.bonus_type = 'Welcome Bonus'
    WHERE t.type = 'Deposit'
        AND t.transaction_date > bc.bonus_date
    GROUP BY t.player_id
) deposits ON wb.player_id = deposits.player_id
GROUP BY wb.wagering_met;


-- -------------------------------------------------
-- 4. Bonus abuse detection
-- Flag players who take bonuses but generate
-- minimal GGR (possible bonus hunters)
-- -------------------------------------------------
SELECT
    p.player_id,
    p.segment,
    p.country,
    bonus_stats.total_bonuses_received,
    bonus_stats.total_bonus_value,
    COALESCE(ggr_stats.total_ggr, 0) AS total_ggr,
    COALESCE(deposit_stats.total_deposits, 0) AS total_deposits,
    ROUND(
        COALESCE(ggr_stats.total_ggr, 0) / NULLIF(bonus_stats.total_bonus_value, 0), 2
    ) AS ggr_to_bonus_ratio
FROM players p
JOIN (
    SELECT player_id,
           COUNT(*) AS total_bonuses_received,
           SUM(bonus_amount) AS total_bonus_value
    FROM bonus_campaigns
    GROUP BY player_id
    HAVING COUNT(*) >= 3
) bonus_stats ON p.player_id = bonus_stats.player_id
LEFT JOIN (
    SELECT player_id, SUM(ggr) AS total_ggr
    FROM game_sessions
    GROUP BY player_id
) ggr_stats ON p.player_id = ggr_stats.player_id
LEFT JOIN (
    SELECT player_id, SUM(amount) AS total_deposits
    FROM transactions WHERE type = 'Deposit'
    GROUP BY player_id
) deposit_stats ON p.player_id = deposit_stats.player_id
WHERE COALESCE(ggr_stats.total_ggr, 0) / NULLIF(bonus_stats.total_bonus_value, 0) < 0.5
ORDER BY bonus_stats.total_bonus_value DESC
LIMIT 20;
