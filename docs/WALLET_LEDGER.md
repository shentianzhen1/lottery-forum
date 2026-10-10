# 钱包账本

状态：规则已有测试。早期草案见 `docs/POINTS_LEDGER.md`，本文覆盖当前契约。

积分不是现金。不设充值、提现、兑付或用户间转账。

## 规则

- 只使用正整数。
- 账面余额是分录投影，不能直接修改。
- 可用余额等于账面余额减去有效冻结。
- 分录只追加。纠错新增反向分录并引用原记录。
- 幂等键按账户唯一。相同键返回原记录，参数不同则拒绝。
- 可用余额不足时拒绝扣减。冻结不改变账面余额。

## 原因

已有 `opening_grant`、`game_settlement`、`correction`、`freeze`、`release`。没有 `recharge`、`withdraw`、`transfer`。

## 存储

目标是 PostgreSQL 迁移。当前测试和默认运行使用 SQLite 文件。PostgreSQL 尚未实际连接。
