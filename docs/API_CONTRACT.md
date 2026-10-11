# API 契约

前缀：`/api/v1`。除健康检查、注册、登录、玩法列表/校验、以及首页横幅与公告只读外，接口都需要登录用户自己的令牌。错误体为 `{"code","message"}`。

未列出的路径表示尚未实现，不能当成可用接口。

## 产品口径：版主赔付

该玩法下注由**开设该玩法版块的版主**承担赔付（非平台兑付 / 非平台现金出账）。`payout_formula` 仍为 `unset`；本片只推进期号到 `SETTLING` 并可落 `WIN`/`LOSS`/`VOID` 结算记录，**不写派奖分录、不扣版主冻结池**。真实扣付与赔率公式见 `docs/BACKLOG.md`。

## 已实现

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `GET /points/balance`：返回 `balance`、`frozen`、`available`
- `GET /points/entries`
- `GET /games`
- `POST /games/{game_id}/validate`
- `POST /games/{game_id}/entries`：只对临时示例扣固定 10 积分，不派奖（`stake_enabled` 玩法，含 `number-pick` / `fujian-31`）
- `GET /moderator/settings`：返回 `{"threshold": …}`，默认门槛 10000
- `POST /moderator/boards`：请求体 `{"lottery_id"}`；达标则冻结门槛积分并开通版块，返回含 `approval: not_required`、`payout_formula: unset`；可用积分不足返回 `INSUFFICIENT_POINTS`；同一彩种已开通则幂等返回原版块
- `GET /moderator/boards/me`：返回当前账号已开通的版块列表
- `POST /rounds`：请求体 `{"lottery_id", "code?"}`；创建期号，初始状态 `UPCOMING`
- `GET /rounds`：可选 `lottery_id` 过滤；返回 `{"rounds":[…]}`
- `GET /rounds/{round_id}`：期号不存在返回 `ROUND_NOT_FOUND`
- `POST /rounds/{round_id}/open`：仅 `UPCOMING` → `OPEN`；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/close`：仅 `OPEN` → `CLOSED`；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/draw`：仅 `CLOSED` → `DRAWN`（已开奖）；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/settling`：仅 `DRAWN` → `SETTLING`（结算中）；非法跳转返回 `INVALID_TRANSITION`；本片不停在 `SETTLED`
- `POST /bets`：请求体必须含 `idempotency_key`、`round_id`、`play_id`、`rule_version`，以及玩法选号字段（如 `numbers` / `ranking`）。须挂在 `OPEN` 期号上；流程为校验→记录→冻结占位（固定 10 积分，仅 `stake_enabled` 玩法）。成功状态为 `ACCEPTED`（积分已冻结；`LOCKED` 留给期号截止后再推进）。`odds_snapshot` 与冻结分存，本片为 `{"status":"unset"}`，不派奖。非 `OPEN` 返回 `ROUND_CLOSED`；选号失败 `INVALID_SELECTION`；积分不足 `INSUFFICIENT_POINTS`；相同幂等键返回原单不重复冻结；未开放投注冻结的玩法返回 `STAKE_DISABLED`（当前示例玩法均已开放：`number-pick` / `ranking-pick` / `fujian-31`）
- `GET /bets/{bet_id}`：仅本人投注；不存在返回 `BET_NOT_FOUND`
- `POST /settlements/{round_id}`：请求体 `{"results":[{"bet_id","result"},…]}`，`result` 仅 `WIN` / `LOSS` / `VOID`。期号须为 `SETTLING`；为该期投注落结算记录，**不写派奖分录、不改余额/冻结、不推进投注到 `SETTLED`**。同一 `bet_id` 幂等返回原结果，冲突返回 `SETTLEMENT_CONFLICT`。需登录（本片不做管理员角色校验）
- `GET /settlements/{round_id}`：返回该期已落结算记录列表
- `GET /home/banners`：只读；无需登录。返回 `{"banners":[…]}`，字段 `id`/`title`/`subtitle`/`image_key`/`sort_order`/`enabled`；仅 `enabled`，按 `sort_order` 升序，最多 5 条；空列表时客户端不占位
- `GET /home/announcements`：只读；无需登录。返回 `{"announcements":[…]}`，字段 `id`/`title`/`body`/`published_at`/`pinned`；置顶优先、再按 `published_at` 倒序，最多 4 条；空列表时客户端显示「暂无公告」

没有 `POST /points/transfer`、充值或提现路径。玩法赔付只通过结算分录入账（真实派奖尚未实现）。开通版主达到后台门槛后冻结积分，不需要人工批准；冻结不是转账。默认门槛是 10000 积分。

本片期号状态机可演示到 `SETTLING`。不提供进入 `SETTLED` 的推进，也不做真实派奖。

本片投注生命周期仍只做到 `ACCEPTED` + 冻结占位。不提供 `cancel`；结算记录不推进投注状态。

### 期号状态（API 枚举 / 中文展示）

| 枚举 | 中文 |
| --- | --- |
| `UPCOMING` | 未开售 |
| `OPEN` | 销售中 |
| `CLOSED` | 已截止 |
| `DRAWN` | 已开奖 |
| `SETTLING` | 结算中 |
| `SETTLED` | 已结算 |

客户端展示用中文，不直接显示英文码。本片可演示：`UPCOMING`（未开售）→ `OPEN`（销售中）→ `CLOSED`（已截止）→ `DRAWN`（已开奖）→ `SETTLING`（结算中）。`SETTLED`（已结算）仅预留枚举，尚无推进接口。

### 投注状态（API 枚举 / 中文展示）

| 枚举 | 中文 |
| --- | --- |
| `CREATED` | 已创建 |
| `ACCEPTED` | 已受理 |
| `LOCKED` | 已锁定 |
| `SETTLED` | 已结算 |
| `REJECTED` | 已拒绝 |
| `CANCELLED` | 已取消 |
| `REFUNDED` | 已退回 |

客户端展示用中文，不直接显示英文码。本片成功投注落在 `ACCEPTED`（已受理）并冻结占位；`LOCKED` / `SETTLED` 及取消、退回尚未开放。

### 结算结果（API 枚举 / 中文展示）

| 枚举 | 中文 |
| --- | --- |
| `WIN` | 中奖 |
| `LOSS` | 未中 |
| `VOID` | 作废 |

本片只落记录，不触发派奖分录。

### 投注提示文案

- 成功：「投注已受理（积分已冻结占位，暂不派奖）」
- `ROUND_CLOSED`：「当期已截止，无法投注」（当前 `UPCOMING` 未开售也共用此码与文案；拆「未开售」见 `docs/BACKLOG.md`）
- 选号校验失败：「选号未通过校验」
- 积分不足：「积分不足」
- 幂等命中：「已提交过，返回原投注」


### 首页横幅与公告（本片只读）

- 区标题：「平台公告」；空态客户端显示「暂无公告」
- 有公告：标题 + 摘要（取 `body` 前一两行）；置顶项标「置顶」；本片不进详情、无管理后台
- 横幅：主文 `title`、副文 `subtitle`；空列表不占位、不显示假图；本片不点跳、不编辑
- 不做管理后台或写接口；可选本地种子：`LOTTERY_FORUM_HOME_SEED=1`

## 预定但未实现

- `GET /lotteries`、`GET /lotteries/{lottery_id}`
- 进入 `SETTLED` 的期号推进、真实派奖分录、版主冻结池扣付
- `POST /bets/{bet_id}/cancel`：只允许 `OPEN` 期号内、未锁定的投注
- `POST /banker/sessions`、`GET /banker/sessions/me`
- `POST /banker/offers`：保存积分赔率快照，不接收现金金额
- `GET /market/offers`
- `GET /admin/audit`

## 状态约束

期号关闭后，`POST /bets` 必须返回 `ROUND_CLOSED`。重复幂等键返回原记录，不能重复冻结或扣分。结算只追加分录（真实派奖尚未开放）。版主开通不需要审批；不能设置后台门槛或改其他版主的配置。
