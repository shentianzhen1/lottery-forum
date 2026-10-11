import os
from dataclasses import dataclass
from pathlib import Path

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.bets.service import BetService
from app.bets.store import BetStore
from app.db import connect
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.games.selections import SelectionStore
from app.home.service import HomeService
from app.home.store import HomeStore
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore
from app.moderator.service import ModeratorService
from app.moderator.store import ModeratorStore
from app.rounds.service import RoundService
from app.rounds.store import RoundStore
from app.settlements.service import SettlementService
from app.settlements.store import SettlementStore


@dataclass
class AppState:
    auth: AuthService
    ledger: LedgerService
    games: GameRegistry
    participation: GameParticipation
    selections: SelectionStore
    moderator: ModeratorService
    rounds: RoundService
    bets: BetService
    home: HomeService
    settlements: SettlementService


def build_state(database: Path | None = None) -> AppState:
    database = database or Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
    if database.name != ":memory:":
        database.parent.mkdir(parents=True, exist_ok=True)
    connection = connect(database)
    ledger = LedgerService(SqliteLedgerStore(connection=connection))
    games = GameRegistry()
    round_store = RoundStore(connection=connection)
    rounds = RoundService(round_store)
    bet_store = BetStore(connection=connection)
    home = HomeService(HomeStore(connection=connection))
    if os.environ.get("LOTTERY_FORUM_HOME_SEED") == "1":
        home.seed_demo()
    return AppState(
        AuthService(AccountStore(connection=connection), ledger),
        ledger,
        games,
        GameParticipation(games, ledger),
        SelectionStore(connection=connection),
        ModeratorService(ModeratorStore(connection=connection), ledger),
        rounds,
        BetService(bet_store, rounds, games, ledger),
        home,
        SettlementService(SettlementStore(connection=connection), rounds, bet_store),
    )
