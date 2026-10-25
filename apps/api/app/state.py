import os
from dataclasses import dataclass
from pathlib import Path

from app.auth.service import AuthService
from app.auth.store import AccountStore
from app.bets.service import BetService
from app.bets.store import BetStore
from app.db import connect
from app.draws.ingestion import DrawIngestionService
from app.draws.reconciliation import DrawReconciliationService
from app.draws.result_service import DrawResultService
from app.draws.result_store import DrawResultStore
from app.draws.service import DrawObservationService
from app.draws.store import DrawObservationStore
from app.games.participation import GameParticipation
from app.games.registry import GameRegistry
from app.games.selections import SelectionStore
from app.home.service import HomeService
from app.home.store import HomeStore
from app.ledger.service import LedgerService
from app.ledger.sqlite_store import SqliteLedgerStore
from app.moderator.dev_seed import seed_moderators_from_env
from app.moderator.service import ModeratorService
from app.moderator.store import ModeratorStore
from app.rounds.dev_seed import seed_open_rounds_from_env
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
    draws: DrawObservationService
    draw_results: DrawResultService
    draw_ingestion: DrawIngestionService
    draw_reconciliation: DrawReconciliationService


def build_state(database: Path | None = None) -> AppState:
    database = database or Path(os.environ.get("LOTTERY_FORUM_DB", "data/lottery-forum.sqlite"))
    if database.name != ":memory:":
        database.parent.mkdir(parents=True, exist_ok=True)
    connection = connect(database)
    ledger = LedgerService(SqliteLedgerStore(connection=connection))
    games = GameRegistry()
    moderator_store = ModeratorStore(connection=connection)
    moderator = ModeratorService(moderator_store, ledger)
    round_store = RoundStore(connection=connection)
    rounds = RoundService(round_store, moderator_store.get)
    bet_store = BetStore(connection=connection)
    settlement_store = SettlementStore(connection=connection)
    home = HomeService(HomeStore(connection=connection))
    draw_observation_store = DrawObservationStore(connection=connection)
    draw_result_store = DrawResultStore(connection=connection)
    draws = DrawObservationService(draw_observation_store)
    draw_results = DrawResultService(draw_observation_store, draw_result_store)
    draw_ingestion = DrawIngestionService(draws)
    draw_reconciliation = DrawReconciliationService(draw_observation_store, draw_result_store)
    if os.environ.get("LOTTERY_FORUM_HOME_SEED") == "1":
        home.seed_demo()
    auth = AuthService(AccountStore(connection=connection), ledger)
    # Local/test only; no-op unless LOTTERY_FORUM_DEV_SEED_MODERATORS is set.
    seed_moderators_from_env(auth, ledger, moderator)
    # Local/test only; no-op unless LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS is set.
    # Runs after moderator seed so existing boards can be attached.
    seed_open_rounds_from_env(rounds, moderator_store)
    bets = BetService(bet_store, rounds, games, ledger, settlement_store)
    settlements = SettlementService(settlement_store, rounds, bet_store, ledger)
    return AppState(
        auth,
        ledger,
        games,
        GameParticipation(games, ledger),
        SelectionStore(connection=connection),
        moderator,
        rounds,
        bets,
        home,
        settlements,
        draws,
        draw_results,
        draw_ingestion,
        draw_reconciliation,
    )
