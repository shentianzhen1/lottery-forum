# 彩票论坛

横屏优先的多玩法基础平台。积分账本可追溯，不含现金充值、提现或兑付。

本仓库与 `shentianzhen1/lottery` 无关。不迁入该旧仓的投注、充值、提现或代理开户实现。

## 当前状态

开通版主不需要批准。可用积分达到后台门槛即可开通，默认 10000。见 `docs/decisions/2026-10-10-moderator-self-serve.md`。

积分不能提现或转账，但可以用于玩法赔付和开通版主。边界见 `docs/decisions/2026-10-10-points-boundary.md`。

框架文档见 `docs/ARCHITECTURE.md`、`docs/DOMAIN_MODEL.md`、`docs/API_CONTRACT.md`。首页横幅和公告见 `docs/HOME_BANNER.md`；只读 API 与客户端横屏展示均已接入。待办见 `docs/BACKLOG.md`。

已实现：

- `GET /health`
- 积分钱包写入 SQLite 文件，重启后余额仍在。PostgreSQL 迁移尚未执行
- 福建31选7 可保存校验后的选号记录。重复幂等键不新增
- 可用积分达到默认 10000 即可开通版主版块，不需要批准。开通会冻结门槛积分。本片 WIN 连本带利共 2 倍派奖；客户端开通入口已接入
- 玩法中心：数字选号已挂 `OPEN` 期号并走 `POST /bets` 真实冻结占位（非假扣固定分）；福建31选7 横屏选号也已接同一投注骨架（冻结占位，结算后按结果派奖）；后端已开放任选 2/3/4/5（`fujian-31-any-2`…`any-5`，期号仍 `fujian-31`），客户端入口另片；排名竞猜未接投注
- 首页公告/横幅只读展示已接入：空态「暂无公告」，横幅空不占位；接口 `GET /home/banners`、`GET /home/announcements`
- 宽度低于 960 时提示使用横屏，不把窄屏页伪装成横屏首页
- CI 工作流已添加；是否通过以 GitHub Actions 实际结果为准
- 个人中心可注册、登录和退出。注册发放 100 开户积分
- 期号状态机骨架：可创建/查询，单向推进 `UPCOMING → OPEN → CLOSED → DRAWN → SETTLING → SETTLED`；管理员或该期所属版块的版主可创建和推进到结算中（期号挂 `board_id`）；写结算与进已结算仅管理员
- 结算：管理员可在 `SETTLING` 期写 `WIN`/`LOSS`/`VOID` 记录，再 `POST /rounds/{id}/settled` 入账——`VOID` 解冻退回、`LOSS` 划入版主可用余额、`WIN` 连本带利共 2 倍（版主付盈利 `stake×(倍率−1)`）从版主可用余额派奖（不足整期挡；判断可用不算同批 LOSS）。产品口径：下注由开设该版块的版主赔付
- 投注生命周期骨架：挂 `OPEN` 期号，校验→记录→冻结占位（`ACCEPTED`，`odds_snapshot` 固定 2 倍）；finalize 后 VOID/LOSS/WIN 进 `SETTLED`。不取消

未实现：

- PostgreSQL 尚未连接。当前持久化是 SQLite 文件
- 阶梯/复杂赔率与从开通门槛冻结池扣付（本片仅固定 2 倍、从可用余额派）
- 坐庄引擎（门槛开通与固定 2 倍派奖已落地；坐庄未做）
- 管理后台
- Android 平台文件已生成，测试包默认横屏。可在本机或 GitHub Release/CI 打 debug APK（见 `docs/ANDROID_TEST_BUILD.md`）；仓库不提交 APK 二进制；部分受限环境曾因内存不足导致构建失败，属环境备注
- 真机或模拟器横屏验收

## 本地运行

```bash
python -m pip install -r apps/api/requirements-dev.txt
(cd apps/api && python -m pytest tests)
(cd apps/mobile && flutter pub get && flutter analyze && flutter test)
uvicorn app.main:app --app-dir apps/api --reload
```

期号创建/推进：管理员，或在自己版块上的版主；写结算仅限管理员。管理员本地用 `LOTTERY_FORUM_ADMIN_USERNAMES=alice,bob uvicorn …` 指定（逗号分隔用户名），注册不能自封管理员，详见 `docs/API_CONTRACT.md`。

### 本地演示：开一个销售中期号

期号必须由管理员创建并开售，否则普通账号会拿到 403 `FORBIDDEN`。

```bash
# 1. 启动 API，指定 alice 为管理员
LOTTERY_FORUM_ADMIN_USERNAMES=alice uvicorn app.main:app --app-dir apps/api --reload

# 2. 注册 alice，拿到令牌（注册请求里带 role 会被忽略）
curl -s -X POST localhost:8000/api/v1/auth/register \
  -H 'Content-Type: application/json' -d '{"username":"alice","password":"secret-pass"}'
TOKEN=<上一步返回的 token>

# 3. 创建期号并开售；数字选号用 demo-digit，福建31选7 用 fujian-31
curl -s -X POST localhost:8000/api/v1/rounds -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' -d '{"lottery_id":"demo-digit"}'
curl -s -X POST localhost:8000/api/v1/rounds/<round_id>/open -H "Authorization: Bearer $TOKEN"
```

之后客户端玩法中心就能找到该彩种的销售中期号并下单。普通账号照常注册、下注，不需要管理员权限。

### 本地演示：版主在自己版块开期号

开版块要 10000 积分门槛。本地可用启动种子直接造两个版主（**仅限本地/测试，线上不要设**；不设就什么都不发生，也没有任何加积分接口）：

```bash
# 1. 启动 API：种子建 alice（福建31版块）和 bob（数字选号版块），密码默认 secret-pass
LOTTERY_FORUM_DEV_SEED_MODERATORS=alice:fujian-31,bob:demo-digit \
  uvicorn app.main:app --app-dir apps/api --reload

# 2. 两人登录，各自查自己的版块
curl -s -X POST localhost:8000/api/v1/auth/login \
  -H 'Content-Type: application/json' -d '{"username":"alice","password":"secret-pass"}'
ALICE=<alice 的 token>   # bob 同理得到 BOB
curl -s localhost:8000/api/v1/moderator/boards/me -H "Authorization: Bearer $ALICE"
BOARD=<alice 的 board_id>

# 3. alice 在自己版块建福建31期号并开售（board_id 必填，lottery_id 须与版块一致）
curl -s -X POST localhost:8000/api/v1/rounds -H "Authorization: Bearer $ALICE" \
  -H 'Content-Type: application/json' -d "{\"lottery_id\":\"fujian-31\",\"board_id\":\"$BOARD\"}"
curl -s -X POST localhost:8000/api/v1/rounds/<round_id>/open -H "Authorization: Bearer $ALICE"

# 4. bob 动 alice 的期号 → 403 FORBIDDEN「无权限执行此操作」
curl -s -X POST localhost:8000/api/v1/rounds/<round_id>/close -H "Authorization: Bearer $BOB"
```

版主能建号、开售、截止、开奖、进结算中，但**写结算（`POST /settlements/{round_id}`）仍只限管理员**。可与 `LOTTERY_FORUM_ADMIN_USERNAMES` 同时设置。种子密码可用 `LOTTERY_FORUM_DEV_SEED_PASSWORD` 改。

不全局锁定屏幕方向。主要页面仍以 16:9 横屏为第一验收方向。
