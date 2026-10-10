# API 契约

前缀：`/api/v1`。除健康检查、注册、登录和玩法校验外，接口都需要登录用户自己的令牌。错误体为 `{"code","message"}`。

未列出的路径表示尚未实现，不能当成可用接口。

## 已实现

- `GET /health`
- `POST /auth/register`
- `POST /auth/login`
- `GET /points/balance`：返回 `balance`、`frozen`、`available`
- `GET /points/entries`
- `GET /games`
- `POST /games/{game_id}/validate`
- `POST /games/{game_id}/entries`：只对临时示例扣固定 10 积分，不派奖。`fujian-31` 返回 `STAKE_DISABLED`

没有 `POST /points/transfer`、充值或提现路径。玩法赔付只通过结算分录入账。申请版主达到后台门槛后冻结积分，不需要人工批准；冻结不是转账。默认门槛是 10000 积分。

## 预定但未实现

- `GET /lotteries`、`GET /lotteries/{lottery_id}`
- `POST /rounds`、`GET /rounds/{round_id}`、`POST /rounds/{round_id}/close`、`POST /rounds/{round_id}/draw`
- `POST /bets`：必须带 `idempotency_key`、`round_id`、`play_id`、`rule_version`
- `GET /bets/{bet_id}`
- `POST /bets/{bet_id}/cancel`：只允许 `OPEN` 期号内、未锁定的投注
- `POST /settlements/{round_id}`：只允许服务内部或管理员触发
- `POST /banker/sessions`、`GET /banker/sessions/me`
- `POST /banker/offers`：保存积分赔率快照，不接收现金金额
- `GET /market/offers`
- `GET /admin/audit`

## 状态约束

期号关闭后，`POST /bets` 必须返回 `ROUND_CLOSED`。重复幂等键返回原记录，不能重复冻结或扣分。结算只追加分录。版主开通不需要审批；不能设置后台门槛或改其他版主的配置。
