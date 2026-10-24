import hashlib
import json
from datetime import date, datetime, timezone
from uuid import uuid4

from app.db import atomic_command
from app.draws.store import DrawObservationStore


class DrawObservationError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class DrawObservationService:
    def __init__(self, store: DrawObservationStore) -> None:
        self.store = store

    @atomic_command
    def record(self, payload: dict[str, object]) -> dict[str, object]:
        provider = self._required_text(payload, "provider", "缺少开奖数据来源")
        lottery_id = self._required_text(payload, "lottery_id", "缺少彩种")
        raw_code = self._required_text(payload, "raw_code", "缺少原始期号")
        normalized_code = self._required_text(payload, "normalized_code", "缺少规范期号")
        draw_date = self._required_text(payload, "draw_date", "缺少开奖日期")
        raw_payload = payload.get("raw_payload")
        if not isinstance(raw_payload, dict):
            raise DrawObservationError("INVALID_DRAW_PAYLOAD", "原始开奖数据须为对象")

        try:
            date.fromisoformat(draw_date)
        except ValueError as error:
            raise DrawObservationError("INVALID_DRAW_DATE", "开奖日期须为 YYYY-MM-DD") from error

        main_numbers = self._number_list(payload.get("main_numbers"), "main_numbers")
        extra_numbers = self._number_list(payload.get("extra_numbers", []), "extra_numbers")
        self._validate_lottery(lottery_id, main_numbers, extra_numbers)

        canonical = json.dumps(
            {
                "provider": provider,
                "lottery_id": lottery_id,
                "raw_code": raw_code,
                "normalized_code": normalized_code,
                "draw_date": draw_date,
                "main_numbers": main_numbers,
                "extra_numbers": extra_numbers,
                "raw_payload": raw_payload,
            },
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        content_hash = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        existing = self.store.find_exact(provider, lottery_id, normalized_code, content_hash)
        if existing is not None:
            return self._observation(existing, duplicate=True)

        version = self.store.next_version(provider, lottery_id, normalized_code)
        observation_id = str(uuid4())
        fetched_at = datetime.now(timezone.utc).isoformat()
        self.store.add(
            observation_id=observation_id,
            provider=provider,
            lottery_id=lottery_id,
            raw_code=raw_code,
            normalized_code=normalized_code,
            draw_date=draw_date,
            main_numbers_json=json.dumps(main_numbers, ensure_ascii=False),
            extra_numbers_json=json.dumps(extra_numbers, ensure_ascii=False),
            raw_payload_json=json.dumps(raw_payload, ensure_ascii=False, sort_keys=True),
            content_hash=content_hash,
            fetched_at=fetched_at,
            version=version,
            status="PENDING_REVIEW",
        )
        return self._observation(self.store.get(observation_id), duplicate=False)

    def list_observations(
        self,
        *,
        lottery_id: str | None = None,
        normalized_code: str | None = None,
        provider: str | None = None,
    ) -> dict[str, object]:
        rows = self.store.list(
            lottery_id=lottery_id,
            normalized_code=normalized_code,
            provider=provider,
        )
        return {"items": [self._observation(row) for row in rows]}

    @staticmethod
    def _required_text(payload: dict[str, object], field: str, message: str) -> str:
        value = payload.get(field)
        if not isinstance(value, str) or not value.strip():
            raise DrawObservationError("INVALID_DRAW_OBSERVATION", message)
        return value.strip()

    @staticmethod
    def _number_list(value: object, field: str) -> list[int]:
        if not isinstance(value, list):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", f"{field} 须为号码数组")
        if any(not isinstance(item, int) or isinstance(item, bool) for item in value):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "开奖号码须为整数")
        return list(value)

    @staticmethod
    def _validate_lottery(lottery_id: str, main_numbers: list[int], extra_numbers: list[int]) -> None:
        if lottery_id != "fujian-31":
            raise DrawObservationError("DRAW_LOTTERY_UNSUPPORTED", "当前开奖采集仅支持福建31")
        if len(main_numbers) != 7:
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "福建31基本号必须为 7 个")
        if len(set(main_numbers)) != len(main_numbers):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "福建31基本号不能重复")
        if any(number < 1 or number > 31 for number in main_numbers):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "福建31基本号必须为 1 到 31")
        if len(set(extra_numbers)) != len(extra_numbers):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "附加号码不能重复")
        if any(number < 1 or number > 31 for number in extra_numbers):
            raise DrawObservationError("INVALID_DRAW_NUMBERS", "附加号码必须为 1 到 31")

    @staticmethod
    def _observation(row: object, duplicate: bool | None = None) -> dict[str, object]:
        body: dict[str, object] = {
            "observation_id": row["observation_id"],  # type: ignore[index]
            "provider": row["provider"],  # type: ignore[index]
            "lottery_id": row["lottery_id"],  # type: ignore[index]
            "raw_code": row["raw_code"],  # type: ignore[index]
            "normalized_code": row["normalized_code"],  # type: ignore[index]
            "draw_date": row["draw_date"],  # type: ignore[index]
            "main_numbers": json.loads(row["main_numbers_json"]),  # type: ignore[index]
            "extra_numbers": json.loads(row["extra_numbers_json"]),  # type: ignore[index]
            "raw_payload": json.loads(row["raw_payload_json"]),  # type: ignore[index]
            "content_hash": row["content_hash"],  # type: ignore[index]
            "fetched_at": row["fetched_at"],  # type: ignore[index]
            "version": int(row["version"]),  # type: ignore[index]
            "status": row["status"],  # type: ignore[index]
        }
        if duplicate is not None:
            body["duplicate"] = duplicate
        return body
