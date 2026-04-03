-- =============================================
-- SCHEMA: Create tables and load CSV data
-- Run this first to set up your database
-- =============================================
-- If using SQLite:    sqlite3 igaming.db < 01_schema.sql
-- If using MySQL:     mysql -u root -p igaming < 01_schema.sql
-- If using PostgreSQL: psql -U postgres -d igaming -f 01_schema.sql

-- NOTE: The .import commands below are for SQLite.
-- For MySQL/PostgreSQL, use LOAD DATA INFILE or \copy instead.


-- Drop tables if they exist (fresh start)
DROP TABLE IF EXISTS bonus_campaigns;
DROP TABLE IF EXISTS game_sessions;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS players;


-- Players table
CREATE TABLE players (
    player_id TEXT PRIMARY KEY,
    registration_date DATE NOT NULL,
    country TEXT NOT NULL,
    segment TEXT NOT NULL,          -- Casual, Regular, VIP, Whale
    status TEXT NOT NULL,           -- Active, Inactive, Self-Excluded, Dormant
    preferred_game TEXT NOT NULL,
    deposit_method TEXT NOT NULL,
    last_login DATE,
    kyc_verified TEXT NOT NULL      -- Yes / No
);


-- Transactions (deposits and withdrawals)
CREATE TABLE transactions (
    transaction_id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    transaction_date DATE NOT NULL,
    type TEXT NOT NULL,             -- Deposit / Withdrawal
    amount REAL NOT NULL,
    method TEXT NOT NULL,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);


-- Game sessions
CREATE TABLE game_sessions (
    session_id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    session_date DATE NOT NULL,
    game_type TEXT NOT NULL,
    total_bets REAL NOT NULL,
    total_wins REAL NOT NULL,
    ggr REAL NOT NULL,              -- Gross Gaming Revenue = bets - wins
    duration_minutes INTEGER NOT NULL,
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);


-- Bonus campaigns
CREATE TABLE bonus_campaigns (
    bonus_id TEXT PRIMARY KEY,
    player_id TEXT NOT NULL,
    bonus_type TEXT NOT NULL,
    bonus_date DATE NOT NULL,
    bonus_amount REAL NOT NULL,
    wagering_requirement INTEGER NOT NULL,
    wagering_met TEXT NOT NULL,     -- Yes / No
    bonus_cost REAL NOT NULL,       -- Actual cost to the house
    FOREIGN KEY (player_id) REFERENCES players(player_id)
);


-- =============================================
-- LOAD DATA (SQLite version)
-- Make sure CSV files are in the same directory
-- =============================================

-- For SQLite, run these commands in the sqlite3 shell:
-- .mode csv
-- .import --skip 1 players.csv players
-- .import --skip 1 transactions.csv transactions
-- .import --skip 1 game_sessions.csv game_sessions
-- .import --skip 1 bonus_campaigns.csv bonus_campaigns
