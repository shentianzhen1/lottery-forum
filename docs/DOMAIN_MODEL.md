# 领域模型

状态：2026-10-09 按 Framework V0.1 规划书写的契约。除特别标明外，对象尚未实现。

积分是平台内部记账单位。不能提现、转账或兑付。可以用于玩法赔付，也可以在开通版主时冻结。本模型不包含充值、提现、兑付或用户间转账。

## User

已有注册和登录。字段：`account_id`、`username`、`password_hash`、`role`。角色尚未用于授权。

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

未实现为独立配置。当前示例是 `number-pick`、`ranking-pick`、`fujian-31`。玩法必须声明 `rule_version` 和 `stake_enabled`。Demo 不能绕过钱包、期号和投注对象。

## Round

未实现。状态只能按这个顺序变化：

`UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`

关闭后不能新增投注。开奖结果写入后不能覆盖，只能追加纠错记录。

## Bet / BetItem

未实现完整生命周期。预定状态：

`CREATED` → `ACCEPTED` → `LOCKED` → `SETTLED`

异常终态：`REJECTED`、`CANCELLED`、`REFUNDED`。

BetItem 必须保存 `play_id`、`round_id`、`rule_version` 和 `odds_snapshot`。福建 31 选 7 当前只有选号校验，选号记录尚未进入 `main`，不扣分。

## Settlement

未实现。结果只允许 `WIN`、`LOSS`、`VOID`。派奖和退回都必须写成账本分录，不能直接改余额。

## BankerSession / BankerOffer

未实现。版主中心管理自己的玩法、赔率快照、手续费策略和保证金。版主市场只展示已发布的积分盘口。开通版主为达标自助、无需人工审核；用户不能修改后台门槛或他人盘口。

## RiskSnapshot

未实现。`RiskCalculator.evaluate` 返回快照，`can_accept` 决定是否接单。阈值未定，不能用占位数字当作规则。
