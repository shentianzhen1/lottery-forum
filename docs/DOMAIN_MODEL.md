# 领域模型

状态：与 main 对齐的 Framework V0.1 契约。下列对象中，已标明「已实现/骨架」的以代码为准；其余仍为规划。

积分是平台内部记账单位。不能提现、转账或兑付。可以用于玩法赔付，也可以在开通版主时冻结。本模型不包含充值、提现、兑付或用户间转账。

**产品口径**：该玩法下注由**开设该玩法版块的版主**承担赔付（非平台兑付）。本片 `WIN` 连本带利共 2 倍：解冻退回注额后，版主从可用余额付盈利 `stake × (倍率 − 1)`；版主版块字段 `payout_formula` 仍可显示 `unset`（配置位），实际结算以投注 `odds_snapshot` 为准。

## User

已有注册和登录。字段：`account_id`、`username`、`password_hash`、`role`。角色已用于授权：`admin` 可创建/推进任意期号与写结算（来源：`LOTTERY_FORUM_ADMIN_USERNAMES` 或本地种子；注册一律 `user`）。版主不是角色，而是「开设了某版块（`ModeratorBoard`）的账号」，按版块归属授权。

## Wallet

一个用户一个积分钱包。

- `balance`：账面余额，只由分录投影。
- `frozen`：有效冻结合计。
- `available`：账面余额减去冻结。
- 余额不能由玩法或页面直接修改。

## LedgerEntry

只追加，不删除。已有入账、扣减、幂等键和纠错。冻结记录已有，解除后保留。

## LotteryDefinition

未实现。预定字段：`lottery_id`、`schema_version`、`enabled`。V0.1 只登记 DemoDigit、DemoRanking、DemoPick。

## PlayDefinition

未实现为独立配置。当前示例是 `number-pick`、`ranking-pick`、`fujian-31`（选7）以及 `fujian-31-any-2`…`any-5`（任选；期号彩种仍 `fujian-31`）。玩法必须声明 `rule_version` 和 `stake_enabled`。Demo 不能绕过钱包、期号和投注对象。

## ModeratorBoard

已实现。字段：`board_id`、`account_id`（开设该版块的版主）、`lottery_id`、`hold_id`（门槛冻结）、`status`（`open`）。同一账号同一彩种只能开一个版块；同一彩种可以有多个版主各自开版块。

## Round

骨架已实现到 `SETTLED`：可创建、查询，并单向推进 `UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`（最后一步仅管理员 finalize）。

字段：`round_id`、`lottery_id`、`code`、`board_id`、`status`。`board_id` 指向开设该版块的版主（该期投注由此版主赔付），`lottery_id` 必须与版块彩种一致；可空，仅用于本片之前建的旧期号与管理员不挂版块创建的期号。推进权限：管理员，或该版块版主；`board_id` 为空时仅管理员。写结算仅管理员（版主是赔付方）。

状态只能按这个顺序变化：

`UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`

中文展示：未开售 / 销售中 / 已截止 / 已开奖 / 结算中 / 已结算。`SETTLED` 已开放（管理员 finalize：VOID 解冻、LOSS 划入版主可用、WIN 连本带利共 2 倍派奖）。本片无开奖号码落库。关闭后不能新增投注。开奖结果写入后不能覆盖，只能追加纠错记录。

## Bet / BetItem

骨架已实现到 `ACCEPTED`：`POST /bets` 校验→记录→冻结占位；`GET /bets/{bet_id}` 可查。状态序：

`CREATED` → `ACCEPTED` → `LOCKED` → `SETTLED`

异常终态：`REJECTED`、`CANCELLED`、`REFUNDED`。

中文展示：已创建 / 已受理 / 已锁定 / 已结算 / 已拒绝 / 已取消 / 已退回。本片成功投注落在 `ACCEPTED` 并冻结固定 10 积分占位；`odds_snapshot` 与冻结分存（本片为 `{"status":"fixed","multiplier":2}`）；不接取消；`POST /rounds/{id}/settled` 后 VOID/LOSS/WIN 投注进 `SETTLED`。须挂在 `OPEN` 期号；`stake_enabled` 玩法（`number-pick` / `ranking-pick` / `fujian-31` / `fujian-31-any-2`…`any-5`）可投。

BetItem 必须保存 `play_id`、`round_id`、`rule_version` 和 `odds_snapshot`。

## HomeBanner / Announcement

只读首页数据已实现：`GET /home/banners`、`GET /home/announcements`。字段与上限见 `docs/HOME_BANNER.md` 与 `docs/API_CONTRACT.md`。无写接口、无管理后台。空横幅为空列表（客户端不占位）；空公告客户端显示「暂无公告」。

## Settlement

骨架已实现：`POST /settlements/{round_id}` 可在 `SETTLING` 期为投注落 `WIN` / `LOSS` / `VOID` 记录；`GET /settlements/{round_id}` 可查。`POST /rounds/{round_id}/settled`（仅管理员）在全部投注已落记录后进入 `SETTLED`：`VOID` 解冻退回、`LOSS` 借记玩家并贷记版主可用余额、`WIN` 解冻后退回注额并由版主付盈利 `stake × (倍率 − 1)`（缺省倍率 2）；判断可用时不算同批 LOSS 入账；版主可用不足则整期挡。门槛冻结池不动。余额变动只能走账本分录。

## BankerSession / BankerOffer

未实现。版主中心管理自己的玩法、赔率快照、手续费策略和保证金。版主市场只展示已发布的积分盘口。开通版主为达标自助、无需人工审核；用户不能修改后台门槛或他人盘口。

## RiskSnapshot

未实现。`RiskCalculator.evaluate` 返回快照，`can_accept` 决定是否接单。阈值未定，不能用占位数字当作规则。
