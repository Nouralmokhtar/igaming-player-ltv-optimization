"""
Generate synthetic iGaming data for portfolio project.
Run this once to create the CSV files used in the SQL analysis.

How to run:
    python generate_data.py
"""

import csv
import random
from datetime import datetime, timedelta

# So results are the same every time
random.seed(42)

# === SETTINGS ===
NUM_PLAYERS = 2000
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2024, 12, 31)

COUNTRIES = ["UK", "Germany", "Malta", "Cyprus", "Brazil", "India", "Canada", "Sweden", "Finland", "Nigeria"]
SEGMENTS = ["Casual", "Regular", "VIP", "Whale"]
SEGMENT_WEIGHTS = [0.50, 0.30, 0.15, 0.05]
GAME_TYPES = ["Slots", "Live Casino", "Table Games", "Sports Betting", "Poker"]
STATUSES = ["Active", "Inactive", "Self-Excluded", "Dormant"]
DEPOSIT_METHODS = ["Credit Card", "E-Wallet", "Bank Transfer", "Crypto"]
BONUS_TYPES = ["Welcome Bonus", "Deposit Match", "Free Spins", "Cashback", "VIP Reload", "No Deposit"]


def random_date(start, end):
    """Pick a random date between start and end."""
    if end < start:
        end = start
    days_between = (end - start).days
    if days_between <= 0:
        return start
    random_days = random.randint(0, days_between)
    return start + timedelta(days=random_days)


def pick_segment():
    """Pick a player segment based on realistic weights."""
    return random.choices(SEGMENTS, weights=SEGMENT_WEIGHTS, k=1)[0]


def generate_players():
    """Create the players table."""
    players = []

    for i in range(1, NUM_PLAYERS + 1):
        segment = pick_segment()
        reg_date = random_date(START_DATE, END_DATE)

        # VIPs and Whales stay active more often
        if segment in ["VIP", "Whale"]:
            status = random.choices(STATUSES, weights=[0.60, 0.20, 0.05, 0.15], k=1)[0]
        else:
            status = random.choices(STATUSES, weights=[0.35, 0.30, 0.10, 0.25], k=1)[0]

        # Last login depends on status
        if status == "Active":
            last_login = random_date(END_DATE - timedelta(days=14), END_DATE)
        elif status == "Dormant":
            last_login = random_date(reg_date, END_DATE - timedelta(days=90))
        else:
            last_login = random_date(reg_date, END_DATE - timedelta(days=30))

        player = {
            "player_id": f"P{i:05d}",
            "registration_date": reg_date.strftime("%Y-%m-%d"),
            "country": random.choice(COUNTRIES),
            "segment": segment,
            "status": status,
            "preferred_game": random.choice(GAME_TYPES),
            "deposit_method": random.choice(DEPOSIT_METHODS),
            "last_login": last_login.strftime("%Y-%m-%d"),
            "kyc_verified": random.choices(["Yes", "No"], weights=[0.75, 0.25], k=1)[0],
        }
        players.append(player)

    return players


def generate_transactions(players):
    """Create deposits and withdrawal transactions for each player."""
    transactions = []
    tx_id = 1

    for player in players:
        reg_date = datetime.strptime(player["registration_date"], "%Y-%m-%d")
        segment = player["segment"]

        # How many transactions based on segment
        if segment == "Whale":
            num_deposits = random.randint(30, 80)
        elif segment == "VIP":
            num_deposits = random.randint(15, 40)
        elif segment == "Regular":
            num_deposits = random.randint(5, 20)
        else:
            num_deposits = random.randint(1, 8)

        for _ in range(num_deposits):
            tx_date = random_date(reg_date, END_DATE)

            # Deposit amount based on segment
            if segment == "Whale":
                amount = round(random.uniform(500, 10000), 2)
            elif segment == "VIP":
                amount = round(random.uniform(100, 2000), 2)
            elif segment == "Regular":
                amount = round(random.uniform(20, 300), 2)
            else:
                amount = round(random.uniform(5, 100), 2)

            transactions.append({
                "transaction_id": f"TX{tx_id:06d}",
                "player_id": player["player_id"],
                "transaction_date": tx_date.strftime("%Y-%m-%d"),
                "type": "Deposit",
                "amount": amount,
                "method": player["deposit_method"],
            })
            tx_id += 1

            # Some players withdraw (30% chance per deposit)
            if random.random() < 0.30:
                wd_date = random_date(tx_date, min(tx_date + timedelta(days=30), END_DATE))
                wd_amount = round(amount * random.uniform(0.3, 1.5), 2)

                transactions.append({
                    "transaction_id": f"TX{tx_id:06d}",
                    "player_id": player["player_id"],
                    "transaction_date": wd_date.strftime("%Y-%m-%d"),
                    "type": "Withdrawal",
                    "amount": wd_amount,
                    "method": player["deposit_method"],
                })
                tx_id += 1

    return transactions


def generate_game_sessions(players):
    """Create game session data showing what players actually play."""
    sessions = []
    session_id = 1

    for player in players:
        reg_date = datetime.strptime(player["registration_date"], "%Y-%m-%d")
        segment = player["segment"]

        if segment == "Whale":
            num_sessions = random.randint(50, 200)
        elif segment == "VIP":
            num_sessions = random.randint(20, 80)
        elif segment == "Regular":
            num_sessions = random.randint(5, 30)
        else:
            num_sessions = random.randint(1, 10)

        for _ in range(num_sessions):
            session_date = random_date(reg_date, END_DATE)

            # Players mostly play their preferred game, sometimes try others
            if random.random() < 0.65:
                game = player["preferred_game"]
            else:
                game = random.choice(GAME_TYPES)

            # Bets and results
            if segment == "Whale":
                total_bets = round(random.uniform(200, 5000), 2)
            elif segment == "VIP":
                total_bets = round(random.uniform(50, 1000), 2)
            elif segment == "Regular":
                total_bets = round(random.uniform(10, 200), 2)
            else:
                total_bets = round(random.uniform(2, 50), 2)

            # House edge varies by game type
            if game == "Slots":
                house_edge = random.uniform(0.03, 0.10)
            elif game == "Live Casino":
                house_edge = random.uniform(0.01, 0.05)
            elif game == "Table Games":
                house_edge = random.uniform(0.01, 0.04)
            elif game == "Sports Betting":
                house_edge = random.uniform(-0.05, 0.15)  # Can lose on sports
            else:
                house_edge = random.uniform(0.02, 0.06)

            ggr = round(total_bets * house_edge, 2)
            duration = random.randint(5, 180)

            sessions.append({
                "session_id": f"S{session_id:07d}",
                "player_id": player["player_id"],
                "session_date": session_date.strftime("%Y-%m-%d"),
                "game_type": game,
                "total_bets": total_bets,
                "total_wins": round(total_bets - ggr, 2),
                "ggr": ggr,
                "duration_minutes": duration,
            })
            session_id += 1

    return sessions


def generate_bonus_campaigns(players):
    """Create bonus/promotion data."""
    bonuses = []
    bonus_id = 1

    for player in players:
        reg_date = datetime.strptime(player["registration_date"], "%Y-%m-%d")
        segment = player["segment"]

        # Everyone gets welcome bonus
        bonuses.append({
            "bonus_id": f"B{bonus_id:06d}",
            "player_id": player["player_id"],
            "bonus_type": "Welcome Bonus",
            "bonus_date": reg_date.strftime("%Y-%m-%d"),
            "bonus_amount": round(random.uniform(10, 100), 2),
            "wagering_requirement": random.choice([20, 25, 30, 35]),
            "wagering_met": random.choices(["Yes", "No"], weights=[0.40, 0.60], k=1)[0],
            "bonus_cost": round(random.uniform(5, 60), 2),
        })
        bonus_id += 1

        # Additional bonuses based on segment
        if segment in ["VIP", "Whale"]:
            extra_bonuses = random.randint(3, 10)
        elif segment == "Regular":
            extra_bonuses = random.randint(1, 4)
        else:
            extra_bonuses = random.randint(0, 1)

        for _ in range(extra_bonuses):
            b_type = random.choice(BONUS_TYPES)
            b_date = random_date(reg_date, END_DATE)
            b_amount = round(random.uniform(10, 500), 2)
            met = random.choices(["Yes", "No"], weights=[0.45, 0.55], k=1)[0]

            bonuses.append({
                "bonus_id": f"B{bonus_id:06d}",
                "player_id": player["player_id"],
                "bonus_type": b_type,
                "bonus_date": b_date.strftime("%Y-%m-%d"),
                "bonus_amount": b_amount,
                "wagering_requirement": random.choice([15, 20, 25, 30, 35, 40]),
                "wagering_met": met,
                "bonus_cost": round(b_amount * random.uniform(0.3, 0.8), 2) if met == "Yes" else 0,
            })
            bonus_id += 1

    return bonuses


def save_to_csv(data, filename, fieldnames):
    """Save a list of dictionaries to a CSV file."""
    with open(filename, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"  Saved {len(data)} rows to {filename}")


# === MAIN ===
if __name__ == "__main__":
    print("Generating iGaming synthetic data...")
    print()

    # Generate all data
    players = generate_players()
    transactions = generate_transactions(players)
    sessions = generate_game_sessions(players)
    bonuses = generate_bonus_campaigns(players)

    # Save to CSV
    save_to_csv(players, "players.csv",
                ["player_id", "registration_date", "country", "segment", "status",
                 "preferred_game", "deposit_method", "last_login", "kyc_verified"])

    save_to_csv(transactions, "transactions.csv",
                ["transaction_id", "player_id", "transaction_date", "type", "amount", "method"])

    save_to_csv(sessions, "game_sessions.csv",
                ["session_id", "player_id", "session_date", "game_type",
                 "total_bets", "total_wins", "ggr", "duration_minutes"])

    save_to_csv(bonuses, "bonus_campaigns.csv",
                ["bonus_id", "player_id", "bonus_type", "bonus_date",
                 "bonus_amount", "wagering_requirement", "wagering_met", "bonus_cost"])

    print()
    print("Done! All CSV files are ready.")
    print(f"  Players:      {len(players)}")
    print(f"  Transactions: {len(transactions)}")
    print(f"  Sessions:     {len(sessions)}")
    print(f"  Bonuses:      {len(bonuses)}")
