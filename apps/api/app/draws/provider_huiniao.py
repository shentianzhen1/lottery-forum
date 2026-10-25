from __future__ import annotations

from datetime import date
from typing import Any

import httpx


class DrawProviderError(Exception):
    def __init__(self, code: str, message: str) -> None:
        self.code = code
        self.message = message
        super().__init__(message)


class HuiniaoDrawProvider:
    """Read-only adapter for Huiniao's Fujian 31-select-7 history endpoint.

    The adapter only fetches and normalizes source observations. It never
    advances rounds, confirms results, judges bets, or touches the ledger.
    """

    provider_name = "huiniao"
    lottery_id = "fujian-31"
    endpoint = "https://api.huiniao.top/interface/home/lotteryHistory"

    _main_fields = ("one", "two", "three", "four", "five", "six", "seven")

    def __init__(
        self,
        client: httpx.Client | None = None,
        *,
        timeout_seconds: float = 5.0,
    ) -> None:
        self._client = client
        self._timeout_seconds = timeout_seconds

    def fetch_recent(self, limit: int = 5) -> list[dict[str, object]]:
        if isinstance(limit, bool) or not isinstance(limit, int) or not 1 <= limit <= 20:
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_LIMIT",
                "单次采集数量必须为 1 到 20",
            )

        if self._client is not None:
            return self._fetch(self._client, limit)

        try:
            with httpx.Client(
                timeout=self._timeout_seconds,
                follow_redirects=True,
                headers={"User-Agent": "caiyou-forum-draw-ingestor/0.1"},
            ) as client:
                return self._fetch(client, limit)
        except DrawProviderError:
            raise
        except httpx.HTTPError as error:
            raise DrawProviderError(
                "DRAW_PROVIDER_UNAVAILABLE",
                "开奖数据源暂时不可用",
            ) from error

    def _fetch(self, client: httpx.Client, limit: int) -> list[dict[str, object]]:
        try:
            response = client.get(
                self.endpoint,
                params={"type": "fj31x7", "page": 1, "limit": limit},
            )
            response.raise_for_status()
        except httpx.HTTPError as error:
            raise DrawProviderError(
                "DRAW_PROVIDER_UNAVAILABLE",
                "开奖数据源暂时不可用",
            ) from error

        try:
            payload = response.json()
        except ValueError as error:
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_RESPONSE",
                "开奖数据源返回的不是有效 JSON",
            ) from error

        if not isinstance(payload, dict):
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_RESPONSE",
                "开奖数据源返回结构异常",
            )
        if payload.get("code") != 1:
            info = payload.get("info")
            message = f"开奖数据源拒绝请求：{info}" if info else "开奖数据源拒绝请求"
            raise DrawProviderError("DRAW_PROVIDER_REJECTED", message)

        data = payload.get("data")
        if not isinstance(data, dict):
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                "开奖数据源缺少 data 字段",
            )
        page_data = data.get("data")
        if not isinstance(page_data, dict):
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                "开奖数据源分页结构异常",
            )
        rows = page_data.get("list")
        if not isinstance(rows, list):
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                "开奖数据源缺少开奖记录列表",
            )

        # Parse and validate the entire requested batch before returning any row.
        # DrawIngestionService only starts persistence after this returns, so one
        # malformed row cannot leave a half-ingested provider batch behind.
        return [self._parse_row(row) for row in rows[:limit]]

    def _parse_row(self, row: Any) -> dict[str, object]:
        if not isinstance(row, dict):
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                "开奖记录不是对象",
            )

        raw_code = self._required_text(row.get("code"), "期号")
        draw_date = self._required_text(row.get("day"), "开奖日期")
        try:
            parsed_date = date.fromisoformat(draw_date)
        except ValueError as error:
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                "开奖日期格式异常",
            ) from error

        main_numbers = [self._number(row.get(field), field) for field in self._main_fields]
        extra_numbers: list[int] = []
        if row.get("eight") not in (None, ""):
            extra_numbers.append(self._number(row.get("eight"), "eight"))
        self._validate_numbers(main_numbers, extra_numbers)

        normalized_code = self._normalize_issue_code(raw_code, parsed_date)
        return {
            "provider": self.provider_name,
            "lottery_id": self.lottery_id,
            "raw_code": raw_code,
            "normalized_code": normalized_code,
            "draw_date": draw_date,
            "main_numbers": main_numbers,
            "extra_numbers": extra_numbers,
            "raw_payload": dict(row),
        }

    @staticmethod
    def _required_text(value: object, label: str) -> str:
        if value is None:
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                f"开奖记录缺少{label}",
            )
        text = str(value).strip()
        if not text:
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                f"开奖记录缺少{label}",
            )
        return text

    @staticmethod
    def _number(value: object, field: str) -> int:
        if isinstance(value, bool) or value is None:
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                f"开奖记录号码字段 {field} 异常",
            )
        try:
            number = int(str(value).strip())
        except (TypeError, ValueError) as error:
            raise DrawProviderError(
                "DRAW_PROVIDER_SCHEMA_CHANGED",
                f"开奖记录号码字段 {field} 异常",
            ) from error
        return number

    @staticmethod
    def _validate_numbers(main_numbers: list[int], extra_numbers: list[int]) -> None:
        if len(main_numbers) != 7:
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_DRAW",
                "开奖数据源的福建31基本号数量异常",
            )
        if len(set(main_numbers)) != len(main_numbers):
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_DRAW",
                "开奖数据源的福建31基本号存在重复",
            )
        if any(number < 1 or number > 31 for number in main_numbers):
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_DRAW",
                "开奖数据源的福建31基本号超出 1 到 31",
            )
        if len(set(extra_numbers)) != len(extra_numbers):
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_DRAW",
                "开奖数据源的附加号码存在重复",
            )
        if any(number < 1 or number > 31 for number in extra_numbers):
            raise DrawProviderError(
                "DRAW_PROVIDER_INVALID_DRAW",
                "开奖数据源的附加号码超出 1 到 31",
            )

    @staticmethod
    def _normalize_issue_code(raw_code: str, draw_date: date) -> str:
        """Normalize only when the source code and draw year agree.

        Huiniao has been observed returning both YYNNN and YYYYNNN shapes.
        We never infer from next_code and never blindly prefix a century.
        """

        if not raw_code.isdigit():
            raise DrawProviderError(
                "DRAW_PROVIDER_ISSUE_CODE_INVALID",
                "开奖数据源期号不是纯数字",
            )

        year = str(draw_date.year)
        if len(raw_code) == 7 and raw_code[:4] == year:
            return raw_code
        if len(raw_code) == 5 and raw_code[:2] == year[2:]:
            return f"{year}{raw_code[2:]}"

        raise DrawProviderError(
            "DRAW_PROVIDER_ISSUE_CODE_INVALID",
            "开奖期号与开奖日期年份不一致，已拒绝自动映射",
        )
