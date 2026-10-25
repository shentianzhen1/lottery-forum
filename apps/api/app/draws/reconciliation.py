from __future__ import annotations

import json
from typing import Any

from app.draws.result_store import DrawResultStore
from app.draws.store import DrawObservationStore


class DrawReconciliationService:
    """Build a read-only cross-source reconciliation report for one draw issue."""

    def __init__(self, observations: DrawObservationStore, results: DrawResultStore) -> None:
        self.observations = observations
        self.results = results

    def report(self, *, lottery_id: str, normalized_code: str) -> dict[str, object]:
        rows = self.observations.list(
            lottery_id=lottery_id,
            normalized_code=normalized_code,
        )

        latest_by_provider: dict[str, Any] = {}
        for row in rows:
            provider = str(row["provider"])
            current = latest_by_provider.get(provider)
            if current is None or int(row["version"]) > int(current["version"]):
                latest_by_provider[provider] = row

        sources = [
            self._source(latest_by_provider[provider])
            for provider in sorted(latest_by_provider)
        ]
        signatures = {
            self._signature_from_source(source)
            for source in sources
        }

        if not sources:
            status = "NO_DATA"
        elif len(sources) == 1:
            status = "SINGLE_SOURCE"
        elif len(signatures) == 1:
            status = "MATCH"
        else:
            status = "CONFLICT"

        confirmed_row = self.results.get_by_issue(lottery_id, normalized_code)
        confirmed = self._confirmed(confirmed_row) if confirmed_row is not None else None
        confirmed_matches: list[str] = []
        confirmed_conflicts: list[str] = []
        if confirmed is not None:
            confirmed_signature = self._signature_from_source(confirmed)
            for source in sources:
                provider = str(source["provider"])
                if self._signature_from_source(source) == confirmed_signature:
                    confirmed_matches.append(provider)
                else:
                    confirmed_conflicts.append(provider)

        return {
            "lottery_id": lottery_id,
            "normalized_code": normalized_code,
            "status": status,
            "source_count": len(sources),
            "providers": [source["provider"] for source in sources],
            "sources": sources,
            "confirmed_result": confirmed,
            "confirmed_matches": confirmed_matches,
            "confirmed_conflicts": confirmed_conflicts,
            "read_only": True,
        }

    @staticmethod
    def _source(row: Any) -> dict[str, object]:
        return {
            "observation_id": row["observation_id"],
            "provider": row["provider"],
            "version": int(row["version"]),
            "draw_date": row["draw_date"],
            "main_numbers": json.loads(row["main_numbers_json"]),
            "extra_numbers": json.loads(row["extra_numbers_json"]),
            "fetched_at": row["fetched_at"],
        }

    @staticmethod
    def _confirmed(row: Any) -> dict[str, object]:
        return {
            "result_id": row["result_id"],
            "observation_id": row["observation_id"],
            "provider": row["provider"],
            "source_version": int(row["source_version"]),
            "draw_date": row["draw_date"],
            "main_numbers": json.loads(row["main_numbers_json"]),
            "extra_numbers": json.loads(row["extra_numbers_json"]),
            "confirmed_at": row["confirmed_at"],
            "status": row["status"],
        }

    @staticmethod
    def _signature_from_source(source: dict[str, object]) -> tuple[object, ...]:
        main_numbers = source.get("main_numbers")
        extra_numbers = source.get("extra_numbers")
        return (
            source.get("draw_date"),
            tuple(sorted(int(value) for value in main_numbers)) if isinstance(main_numbers, list) else (),
            tuple(sorted(int(value) for value in extra_numbers)) if isinstance(extra_numbers, list) else (),
        )
