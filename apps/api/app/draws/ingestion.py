from __future__ import annotations

from app.draws.provider_huiniao import HuiniaoDrawProvider
from app.draws.service import DrawObservationService


class DrawIngestionService:
    """Fetch provider observations and persist them as pending evidence only."""

    def __init__(
        self,
        observations: DrawObservationService,
        huiniao: HuiniaoDrawProvider | None = None,
    ) -> None:
        self.observations = observations
        self.huiniao = huiniao or HuiniaoDrawProvider()

    def pull_huiniao(self, limit: int = 5) -> dict[str, object]:
        payloads = self.huiniao.fetch_recent(limit)
        items = [self.observations.record(payload) for payload in payloads]
        duplicate_count = sum(1 for item in items if item.get("duplicate") is True)
        return {
            "provider": self.huiniao.provider_name,
            "lottery_id": self.huiniao.lottery_id,
            "requested_limit": limit,
            "received": len(payloads),
            "created": len(items) - duplicate_count,
            "duplicates": duplicate_count,
            "items": items,
            "auto_confirmed": 0,
            "ledger_touched": False,
        }
