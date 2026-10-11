# API 契约

前缀：`/api/v1`。除健康检查、注册、登录、玩法列表/校验、以及首页横幅与公告只读外，接口都需要登录用户自己的令牌。错误体为 `{"code","message"}`。

## 权限：管理员与版块版主

期号挂版块（`board_id`，即 `POST /moderator/boards` 开出的版块）。「版块版主」= 开设该版块的账号（`moderator_boards.account_id`），不是一个角色字段。

| 接口 | 管理员 | 该版块版主 | 其他登录用户（含别的版块版主） |
| --- | --- | --- | --- |
| `POST /rounds`（不带 `board_id`） | ✓（旧期号，无归属） | 403 | 403 |
| `POST /rounds`（带 `board_id`） | ✓ 任意版块 | ✓ 仅自己的版块 | 403 |
| `POST /rounds/{id}/open` / `close` / `draw` / `settling` | ✓ | ✓ 仅自己版块的期号 | 403 |
| `POST /rounds/{id}/settled`（finalize VOID/LOSS/WIN） | ✓ | 403 | 403 |
| 上述推进，期号 `board_id` 为空（旧期号） | ✓ | 403 | 403 |
| `POST /settlements/{round_id}` | ✓ | **403** | 403 |
| `GET /rounds`、`GET /rounds/{id}`、`GET /settlements/{id}`、`POST /bets` | ✓ | ✓ | ✓ |

- 越权：HTTP 403，`{"code":"FORBIDDEN","message":"无权限执行此操作"}`。**先判权限再判存在**：非管理员操作不存在的期号、或传了不存在/不属于自己的 `board_id`，一律 403（不泄露存在性）；管理员才会看到 404。
- 未带令牌或令牌失效：仍为 401 `UNAUTHENTICATED`。
- **写结算只限管理员**：版主是该期赔付方（版主赔付），不能自己判自己赔不赔。
- `board_id` 校验（权限通过后）：版块不存在 404 `BOARD_NOT_FOUND`（只有管理员会遇到）；期号 `lottery_id` 与版块彩种不一致 400 `BOARD_LOTTERY_MISMATCH`「期号彩种与版块彩种不一致」。
- `POST /rounds` 对管理员仍允许不带 `board_id`（兼容旧流程），这样建出的期号 `board_id` 为 `null`，只有管理员能推进。
- 只读接口（`GET /rounds`、`GET /rounds/{round_id}`、`GET /settlements/{round_id}`）与 `POST /bets` 不变，普通登录用户可用。

管理员来源（注册不能自封）：

- `POST /auth/register` 请求体只认 `username`、`password`，多余字段（如 `role`）忽略；新账号一律存 `role=user`。
- 环境变量 `LOTTERY_FORUM_ADMIN_USERNAMES`：逗号分隔的用户名列表（首尾空格忽略）。每次鉴权实时读取，名单内账号的有效角色为 `admin`；移出名单即恢复 `user`。
- 本地种子：库里 `accounts.role` 直接写为 `admin` 的账号也视为管理员（仅限运维/本地种子，无接口可改）。
- `GET /users/me` 返回的 `role` 为有效角色。

### 本地造版主种子（仅限本地 / 测试）

开版块要 10000 积分门槛，新注册只有 100。为了本地演示与验收，提供启动时种子，**没有任何 HTTP 接口**：

- `LOTTERY_FORUM_DEV_SEED_MODERATORS`：`username:lottery_id` 逗号分隔，如 `alice:fujian-31,bob:demo-digit`。**默认不设 = 完全不生效**。格式错误时启动失败。
- `LOTTERY_FORUM_DEV_SEED_PASSWORD`：新建种子账号的密码，默认 `secret-pass`（仅本地用；已存在的账号不改密码）。
- 设了之后，API 启动时对每一对：账号不存在则按普通注册建号（`role=user`，含 100 开户积分）→ 写一条账本入账分录（`reason=opening_grant`、`reference_type=dev_seed`、幂等键 `dev-seed:moderator:<lottery_id>`、数额 = 版主门槛）→ 通过正常开版块流程开通并冻结门槛。重启幂等，不会重复加分或重复开版块。
- ⚠️ **线上 / 共享环境禁止设置这两个变量。** 不设时，除注册的 100 开户积分外，没有任何接口能给账号加积分。

### 本地造 OPEN 期种子（仅限本地 / 测试）

玩法中心需要销售中（`OPEN`）期号才能下单。为本地演示提供启动时种子，**没有任何 HTTP 接口**：

- `LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS`：设为 `1` / `true` / `yes`（大小写不敏感）时生效。**默认不设 = 完全不生效**。
- 设了之后，API 启动时给 `demo-digit`、`fujian-31` 各造一期 `OPEN`（先 `UPCOMING` 再推进）。同彩种已有 `OPEN` 则跳过，重启幂等，不会刷出多期。
- 若同进程已开版主种子（或库里已有该彩种版块），会挂上对应 `board_id`；否则 `board_id` 为 `null`（旧期号：可投注，但 `WIN`/`LOSS` 结算需要版块——演示派奖请同时开 `LOTTERY_FORUM_DEV_SEED_MODERATORS`）。
- ⚠️ **线上 / 共享环境禁止设置。** 只限本地演示。

未列出的路径表示尚未实现，不能当成可用接口。

## 产品口径：版主赔付

该玩法下注由**开设该玩法版块的版主**承担赔付（非平台兑付 / 非平台现金出账）。本片赔付口径为**连本带利共 2 倍**：投注时 `odds_snapshot` 写 `{"status":"fixed","multiplier":2}`；中奖时先解冻退回注额，再由版主支付盈利 `payout = stake × (倍率 − 1)`（倍率 2 时盈利=注额；注 10 玩家到手合计 20）。本片可推进到 `SETTLED`：`VOID` 解冻退回玩家，`LOSS` 核销冻结并把注额划入期号 `board_id` 所属版主钱包，`WIN` 从版主可用余额派盈利给玩家。见下方 `POST /rounds/{id}/settled`。

## 已实现

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `GET /points/balance`：返回 `balance`、`frozen`、`available`
- `GET /points/entries`
- `GET /games`
- `POST /games/{game_id}/validate`
- `POST /games/{game_id}/entries`：只对临时示例扣固定 10 积分，不派奖（`stake_enabled` 玩法，含 `number-pick` / `fujian-31` / `fujian-31-any-2`…`any-5`）
- `GET /moderator/settings`：返回 `{"threshold": …}`，默认门槛 10000
- `POST /moderator/boards`：请求体 `{"lottery_id"}`；达标则冻结门槛积分并开通版块，返回含 `approval: not_required`、`payout_formula: unset`；可用积分不足返回 `INSUFFICIENT_POINTS`；同一彩种已开通则幂等返回原版块
- `GET /moderator/boards/me`：返回当前账号已开通的版块列表
- `POST /rounds`：管理员或该版块版主（见权限表）。请求体 `{"lottery_id", "code?", "board_id?"}`；创建期号，初始状态 `UPCOMING`。非管理员必须带自己版块的 `board_id`；`lottery_id` 须与版块彩种一致（`BOARD_LOTTERY_MISMATCH`）
- `GET /rounds`：可选 `lottery_id` 过滤；返回 `{"rounds":[…]}`，每项含 `round_id`/`lottery_id`/`code`/`board_id`/`status`（旧期号 `board_id` 为 `null`）
- `GET /rounds/{round_id}`：字段同上（含 `board_id`）；期号不存在返回 `ROUND_NOT_FOUND`
- `POST /rounds/{round_id}/open`：管理员或该期所属版块版主（旧期号仅管理员）。仅 `UPCOMING` → `OPEN`；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/close`：管理员或该期所属版块版主（旧期号仅管理员）。仅 `OPEN` → `CLOSED`；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/draw`：管理员或该期所属版块版主（旧期号仅管理员）。仅 `CLOSED` → `DRAWN`（已开奖）；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/settling`：管理员或该期所属版块版主（旧期号仅管理员）。仅 `DRAWN` → `SETTLING`（结算中）；非法跳转返回 `INVALID_TRANSITION`
- `POST /rounds/{round_id}/settled`：**仅管理员**。`SETTLING` → `SETTLED`，并按结算结果入账：
  - 期号下每笔投注都必须已有结算记录，否则 400 `SETTLEMENT_INCOMPLETE`
  - 存在任意 `WIN` 或 `LOSS` 且期号 `board_id` 为空 → 400 `BOARD_REQUIRED`
  - `WIN` 派奖盈利合计（各注 `stake × (快照倍率 − 1)`，缺省倍率 2 → 盈利=注额）超过版主**当前可用余额** → 400 `INSUFFICIENT_MODERATOR_POINTS`「版主可用积分不足，无法派奖」；整期不进 `SETTLED`、不写任何派奖/LOSS/VOID 分录（无部分派奖）。**判断可用时不算同批 `LOSS` 将入账的贷记**（保守口径，避免依赖同批入账才够派）
  - `VOID`：解除玩家冻结（积分退回可用），投注标 `SETTLED`
  - `LOSS`：解除玩家冻结，借记玩家注额、贷记版主可用余额（`game_settlement`，幂等键 `loss-debit:{bet_id}` / `loss-credit:{bet_id}`），投注标 `SETTLED`；不进开通门槛冻结池
  - `WIN`：解除玩家冻结（注额退回可用），再从版主可用余额借记盈利额、贷记中奖玩家（幂等键 `win-debit:{bet_id}` / `win-credit:{bet_id}`）；门槛冻结池不动。玩家到手 = 解冻注额 + 盈利 = 注额 × 倍率
  - 已是 `SETTLED` 时幂等返回原状态；不重复解冻/记账
  - 非管理员（含该版块版主）403 `FORBIDDEN`
- `POST /bets`：请求体必须含 `idempotency_key`、`round_id`、`play_id`、`rule_version`，以及玩法选号字段（如 `numbers` / `ranking`）。须挂在 `OPEN` 期号上；流程为校验→记录→冻结占位（固定 10 积分，仅 `stake_enabled` 玩法）。成功状态为 `ACCEPTED`（积分已冻结；`LOCKED` 留给期号截止后再推进）。`odds_snapshot` 与冻结分存，本片为 `{"status":"fixed","multiplier":2}`；finalize 时按快照倍率连本带利派 `WIN`（版主付 `stake × (倍率 − 1)`）。非 `OPEN` 返回 `ROUND_CLOSED`；选号失败 `INVALID_SELECTION`；积分不足 `INSUFFICIENT_POINTS`；相同幂等键返回原单不重复冻结；未开放投注冻结的玩法返回 `STAKE_DISABLED`（当前示例玩法均已开放：`number-pick` / `ranking-pick` / `fujian-31` / `fujian-31-any-2`…`fujian-31-any-5`）。福建31 彩种期号 `lottery_id=fujian-31` 共用；投注 `play_id` 可为选7 `fujian-31` 或任选 `fujian-31-any-2`…`any-5`（从 1–31 选对应个数、不重复；失败码仍 `INVALID_SELECTION`「选号未通过校验」）
- `GET /bets/{bet_id}`：仅本人投注；不存在返回 `BET_NOT_FOUND`
- `POST /settlements/{round_id}`：请求体 `{"results":[{"bet_id","result"},…]}`，`result` 仅 `WIN` / `LOSS` / `VOID`。期号须为 `SETTLING`；为该期投注落结算记录，**本接口仍不改余额/冻结、不推进投注状态**（入账在 `POST /rounds/{id}/settled`）。同一 `bet_id` 幂等返回原结果，冲突返回 `SETTLEMENT_CONFLICT`。**仅管理员**（非管理员 403 `FORBIDDEN`，**包括该版块版主**——版主是赔付方，不能自己判结果）
- `GET /settlements/{round_id}`：返回该期已落结算记录列表
- `GET /home/banners`：只读；无需登录。返回 `{"banners":[…]}`，字段 `id`/`title`/`subtitle`/`image_key`/`sort_order`/`enabled`；仅 `enabled`，按 `sort_order` 升序，最多 5 条；空列表时客户端不占位
- `GET /home/announcements`：只读；无需登录。返回 `{"announcements":[…]}`，字段 `id`/`title`/`body`/`published_at`/`pinned`；置顶优先、再按 `published_at` 倒序，最多 4 条；空列表时客户端显示「暂无公告」

没有 `POST /points/transfer`、充值或提现路径。玩法赔付只通过结算分录入账（本片 `WIN` 连本带利共 2 倍：版主付 `stake × (倍率 − 1)`）。开通版主达到后台门槛后冻结积分，不需要人工批准；冻结不是转账。默认门槛是 10000 积分。

本片期号状态机可演示到 `SETTLED`（仅管理员 finalize）。`WIN` 连本带利共 2 倍，从版主可用余额派盈利。

本片投注生命周期在 finalize 后可到 `SETTLED`（VOID/LOSS/WIN）。不提供 `cancel`。

### 期号状态（API 枚举 / 中文展示）

| 枚举 | 中文 |
| --- | --- |
| `UPCOMING` | 未开售 |
| `OPEN` | 销售中 |
| `CLOSED` | 已截止 |
| `DRAWN` | 已开奖 |
| `SETTLING` | 结算中 |
| `SETTLED` | 已结算 |

客户端展示用中文，不直接显示英文码。本片可演示：`UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`（最后一步仅管理员，且受 VOID/LOSS/WIN 规则约束）。

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

客户端展示用中文，不直接显示英文码。本片成功投注落在 `ACCEPTED`（已受理）并冻结占位；`POST /rounds/{id}/settled` 后 VOID/LOSS/WIN 投注进 `SETTLED`。`LOCKED`、取消、退回尚未开放。

### 结算结果（API 枚举 / 中文展示）

| 枚举 | 中文 |
| --- | --- |
| `WIN` | 中奖 |
| `LOSS` | 未中 |
| `VOID` | 作废 |

落记录本身不入账；进入 `SETTLED` 时才对 `VOID`/`LOSS`/`WIN` 解冻与记账。`WIN` 按快照倍率（缺省 2）连本带利：解冻注额后退回，版主再付 `stake × (倍率 − 1)`。

### 投注提示文案

- 成功：「投注已受理，积分已冻结，结算后按结果派奖」
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
- 阶梯/复杂赔率、从开通门槛冻结池扣付（本片 `WIN` 连本带利共 2 倍从版主可用派盈利已开放）
- `POST /bets/{bet_id}/cancel`：只允许 `OPEN` 期号内、未锁定的投注
- `POST /banker/sessions`、`GET /banker/sessions/me`
- `POST /banker/offers`：保存积分赔率快照，不接收现金金额
- `GET /market/offers`
- `GET /admin/audit`

## 状态约束

期号关闭后，`POST /bets` 必须返回 `ROUND_CLOSED`。重复幂等键返回原记录，不能重复冻结或扣分。结算记录只追加；finalize 时 VOID/LOSS/WIN 写账本分录且须幂等。版主开通不需要审批；不能设置后台门槛或改其他版主的配置。
