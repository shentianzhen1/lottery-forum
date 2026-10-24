import json
from datetime import datetime, timezone
from uuid import uuid4

from app.db import atomic_command, require_shared_connection
from app.draws.result_store import DrawResultStore
from app.draws.store import DrawObservationStore


class DrawResultError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class DrawResultService:
    def __init__(self, observations: DrawObservationStore, store: DrawResultStore) -> None:
        self.observations = observations
        self.store = store
        require_shared_connection(observations, store)

    @atomic_command
    def confirm(self, observation_id: str, confirmed_by: str) -> dict[str, object]:
        observation = self.observations.get(observation_id)
        if observation is None:
            raise DrawResultError("DRAW_OBSERVATION_NOT_FOUND", "开奖观察不存在")

        existing = self.store.get_by_observation(observation_id)
        if existing is not None:
            return self._result(existing, duplicate=True)

        confirmed_issue = self.store.get_by_issue(
            observation["lottery_id"],
            observation["normalized_code"],
        )
        if confirmed_issue is not None:
            raise DrawResultError("DRAW_RESULT_ALREADY_CONFIRMED", "该期已有已确认开奖结果")

        result_id = str(uuid4())
        confirmed_at = datetime.now(timezone.utc).isoformat()
        self.store.add(
            result_id=result_id,
            observation_id=observation_id,
            provider=observation["provider"],
            lottery_id=observation["lottery_id"],
            raw_code=observation["raw_code"],
            normalized_code=observation["normalized_code"],
            draw_date=observation["draw_date"],
            main_numbers_json=observation["main_numbers_json"],
            extra_numbers_json=observation["extra_numbers_json"],
            content_hash=observation["content_hash"],
            source_version=int(observation["version"]),
            confirmed_by=confirmed_by,
            confirmed_at=confirmed_at,
        )
        created = self.store.get_by_observation(observation_id)
        if created is None:
            raise RuntimeError("confirmed draw result was not persisted")
        return self._result(created, duplicate=False)

    def list_results(
        self,
        *,
        lottery_id: str | None = None,
        normalized_code: str | None = None,
    ) -> dict[str, object]:
        rows = self.store.list_results(
            lottery_id=lottery_id,
            normalized_code=normalized_code,
        )
        return {"items": [self._result(row) for row in rows]}

    @staticmethod
    def _result(row: object, duplicate: bool | None = None) -> dict[str, object]:
        body: dict[str, object] = {
            "result_id": row["result_id"],  # type: ignore[index]
            "observation_id": row["observation_id"],  # type: ignore[index]
            "provider": row["provider"],  # type: ignore[index]
            "lottery_id": row["lottery_id"],  # type: ignore[index]
            "raw_code": row["raw_code"],  # type: ignore[index]
            "normalized_code": row["normalized_code"],  # type: ignore[index]
            "draw_date": row["draw_date"],  # type: ignore[index]
            "main_numbers": json.loads(row["main_numbers_json"]),  # type: ignore[index]
            "extra_numbers": json.loads(row["extra_numbers_json"]),  # type: ignore[index]
            "content_hash": row["content_hash"],  # type: ignore[index]
            "source_version": int(row["source_version"]),  # type: ignore[index]
            "confirmed_by": row["confirmed_by"],  # type: ignore[index]
            "confirmed_at": row["confirmed_at"],  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
        }
        if duplicate is not None:
            body["duplicate"] = duplicate
        return body
