from fastapi import APIRouter, HTTPException, Request

from app.home.service import HomeError

router = APIRouter(prefix="/home", tags=["home"])


@router.get("/banners")
def list_banners(request: Request) -> dict[str, object]:
    return {"banners": request.app.state.services.home.list_banners()}


@router.get("/announcements")
def list_announcements(request: Request) -> dict[str, object]:
    return {"announcements": request.app.state.services.home.list_announcements()}


@router.get("/rounds/current")
def get_current_round_status(
    request: Request,
    lottery_id: str = "fujian-31",
) -> dict[str, object]:
    rows = request.app.state.services.rounds.list(lottery_id)
    if not rows:
        return {"round": None}

    # Prefer the lifecycle state users can act on now, then the newest row in
    # the next most relevant state. Internal round/board identifiers stay private.
    priority = ("OPEN", "CLOSED", "DRAWN", "SETTLING", "UPCOMING", "SETTLED")
    selected: dict[str, object] | None = None
    for status in priority:
        for row in reversed(rows):
            if isinstance(row, dict) and row.get("status") == status:
                selected = row
                break
        if selected is not None:
            break

    if selected is None:
        return {"round": None}
    status = str(selected.get("status") or "")
    return {
        "round": {
            "lottery_id": selected.get("lottery_id"),
            "code": selected.get("code"),
            "status": status,
            "accepts_bets": status == "OPEN",
        }
    }


@router.get("/draws/recent")
def list_recent_confirmed_draws(
    request: Request,
    lottery_id: str = "fujian-31",
    limit: int = 3,
) -> dict[str, object]:
    if limit < 1 or limit > 5:
        raise HTTPException(
            status_code=400,
            detail={"code": "INVALID_LIMIT", "message": "最近开奖数量必须为 1 到 5"},
        )

    body = request.app.state.services.draw_results.list_results(lottery_id=lottery_id)
    rows = body.get("items")
    public_rows: list[dict[str, object]] = []
    for row in rows if isinstance(rows, list) else []:
        if not isinstance(row, dict) or row.get("status") != "CONFIRMED":
            continue
        public_rows.append(
            {
                "lottery_id": row.get("lottery_id"),
                "normalized_code": row.get("normalized_code"),
                "draw_date": row.get("draw_date"),
                "main_numbers": row.get("main_numbers", []),
                "extra_numbers": row.get("extra_numbers", []),
                "status": "CONFIRMED",
            }
        )

    public_rows.sort(
        key=lambda row: (str(row.get("draw_date") or ""), str(row.get("normalized_code") or "")),
        reverse=True,
    )
    return {"items": public_rows[:limit]}


@router.get("/announcements/{announcement_id}")
def get_announcement(announcement_id: str, request: Request) -> dict[str, object]:
    try:
        return request.app.state.services.home.get_announcement(announcement_id)
    except HomeError as error:
        status = 404 if error.code == "ANNOUNCEMENT_NOT_FOUND" else 400
        raise HTTPException(status_code=status, detail={"code": error.code, "message": error.message}) from error
