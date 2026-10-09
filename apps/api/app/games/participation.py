from dataclasses import dataclass

from app.games.registry import GameRegistry
from app.ledger.model import Direction, Entry, PostRequest, Reason
from app.ledger.service import LedgerService

STAKE = 10


@dataclass(frozen=True)
class Participation:
    entry: Entry
    normalized: dict[str, object]
    stake: int
    payout: int


class GameParticipation:
    def __init__(self, games: GameRegistry, ledger: LedgerService) -> None:
        self.games = games
        self.ledger = ledger

    def enter(
        self,
        account_id: str,
        game_id: str,
        payload: dict[str, object],
        idempotency_key: str,
    ) -> Participation:
        result = self.games.validate(game_id, payload)
        entry = self.ledger.post(
            PostRequest(
                account_id=account_id,
                direction=Direction.DEBIT,
                amount=STAKE,
                reason=Reason.GAME_SETTLEMENT,
                reference_type="game",
                reference_id=game_id,
                idempotency_key=idempotency_key,
                operator_id=account_id,
                note="固定参与分，不派奖",
            )
        )
        return Participation(entry, result.normalized, STAKE, 0)
