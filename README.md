# 彩友论坛

横屏优先、Flutter 跨平台方向的多玩法积分娱乐平台基础框架。

> 产品边界：积分只用于平台内玩法、版主门槛与结算，不提供现金充值、提现、兑付或玩家之间转账/收款。当前也不包含好友、聊天或社区社交功能。

本仓库与 `shentianzhen1/lottery` 无关，不迁入旧仓的充值、提现、代理开户等实现。

## 当前技术栈

- 客户端：Flutter，当前 Android 优先，主要验收方向为 16:9 横屏。
- API：FastAPI / Python 3.12。
- 持久化：当前 SQLite；关键多步写操作已收口事务边界。
- CI：API 测试 + Flutter analyze/test；主线可构建 Android debug APK。
- Android 测试：同时支持联机版与 `STANDALONE_MODE=true` 单机测试版。
- iOS：业务层按跨平台方式设计，但原生 `ios/` 工程与 TestFlight 流程尚未初始化。

## 已实现

### 账号与积分

- 注册 / 登录 / 退出与 24 小时会话。
- 注册默认发放 100 开户积分。
- 积分钱包、冻结/解冻、流水与幂等写入。
- SQLite 文件持久化，重启后余额保留。
- 玩家没有转账、收款、提现或兑付能力。

### 版主

- “坐庄”产品概念已统一为“版主”。
- 开通版主不需要人工批准；可用积分达到门槛即可开通对应彩种版块。
- 默认门槛为 10000 积分，并冻结为版主门槛占用。
- 版主版块与期号归属已接入。
- 当前赔付公式仍是最小实现，复杂赔率与风险引擎尚未完成。

### 玩法、期号与投注

- 数字选号演示玩法。
- 福建31选7及任选2 / 任选3 / 任选4 / 任选5。
- 玩法与彩种已做强绑定，投注前会阻断跨彩种/串期。
- 期号状态机：`UPCOMING → OPEN → CLOSED → DRAWN → SETTLING → SETTLED`。
- 投注挂 `OPEN` 期号，校验后冻结积分并进入 `ACCEPTED`。
- 本人可在期号仍为 `OPEN` 且投注仍为 `ACCEPTED` 时取消并原子解冻。
- 投注列表与取消接口已开放，客户端已有“本期可取消 / 取消本注”。

### 结算

管理员可在 `SETTLING` 期写入 `WIN / LOSS / VOID`，再推进为 `SETTLED`：

- `VOID`：释放冻结积分；
- `LOSS`：投注积分划入对应版主可用余额；
- `WIN`：当前固定最小口径为连本带利共 2 倍，版主支付盈利部分 `stake × (2 - 1)`；
- 版主余额不足时整期结算会被阻断。

当前固定 2 倍仅是框架最小结算口径，不代表后续福建31等玩法的最终赔率设计。

## 开奖数据链路

福建31已经具备一条“先留证、再复核”的保守链路：

```text
第三方 Provider / 人工来源
        ↓
PENDING_REVIEW observation
        ↓
多来源只读 reconciliation
        ↓
管理员人工 confirm
        ↓
CONFIRMED draw result
```

### huiniao 只读 Provider

管理员可手动触发：

```text
POST /api/v1/draws/providers/huiniao/pull?limit=5
```

当前适配福建31 `fj31x7`：

- 读取 `one..seven` 为 7 个基本号；
- `eight` 只作为附加字段留存，目前不解释业务含义；
- 保存来源原始 row；
- 对 HTTP、坏 JSON、业务错误码、字段变化、号码重复/越界做失败关闭；
- 一批数据会先整体解析校验，通过后才开始写 observation，避免半批次落库；
- 期号只在来源期号与开奖日期年份能够互相校验时规范化，不使用 `next_code` 猜当前期号。

Provider 当前**不会**自动确认开奖结果、推进期号、判奖、结算或触碰积分。

### 多来源只读对账

管理员接口：

```text
GET /api/v1/draws/reconciliation?lottery_id=fujian-31&normalized_code=YYYYNNN
```

对账状态：

- `NO_DATA`：没有 observation；
- `SINGLE_SOURCE`：仅一个来源；
- `MATCH`：至少两个来源的最新版本一致；
- `CONFLICT`：至少两个来源的最新版本存在差异。

同一来源发生更正时，历史版本不覆盖；当前对账只使用该来源最高版本。福建体彩官网人工复核数据可按 observation 录入，例如来源标识 `fjtc-official-manual`，再与 huiniao 做只读对账。

当前仍要求至少连续 7 个实际开奖期与官方公告逐条核对后，才考虑进一步自动化。详见：

- `docs/DRAW_DATA_SOURCES.md`
- `docs/DRAW_INGESTION.md`

## Android 测试方式

### 联机测试版

Flutter 客户端通过 `API_BASE_URL` 连接 FastAPI：

```text
flutter build apk --debug --dart-define="API_BASE_URL=http://<host>:8000"
```

Android 模拟器默认可使用 `http://10.0.2.2:8000`。USB 真机本地调试可配合 `adb reverse`。

### 单机测试版

`STANDALONE_MODE=true` 时无需 Windows、Python API 或局域网：

```text
flutter build apk --debug --dart-define=STANDALONE_MODE=true
```

单机测试环境提供：

- 本地注册 / 登录；
- 初始 1000 测试积分；
- 本地开放期号；
- 投注、冻结与撤单解冻；
- 积分流水；
- 版主测试入口；
- 顶部“单机测试”标识。

当前单机数据驻留内存，App 进程重启后重置；它用于产品流程真机验证，不替代服务端事务、风控和最终结算验收。

## 本地运行

安装并运行 API 测试：

```bash
python -m pip install -r apps/api/requirements-dev.txt
(cd apps/api && python -m pytest tests)
```

运行 Flutter 检查：

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
```

启动 API：

```bash
uvicorn app.main:app --app-dir apps/api --reload
```

本地指定管理员：

```bash
LOTTERY_FORUM_ADMIN_USERNAMES=alice,bob \
  uvicorn app.main:app --app-dir apps/api --reload
```

注册请求不能自行指定管理员角色。

### 本地快速种子

仅限本地/测试，不设置环境变量时不会执行：

```bash
LOTTERY_FORUM_DEV_SEED_MODERATORS=alice:fujian-31,bob:demo-digit \
LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS=1 \
  uvicorn app.main:app --app-dir apps/api --reload
```

可用于快速生成版主版块及 `OPEN` 测试期号。

## 当前主要缺口

按当前收益优先级：

1. 福建31真实开奖源继续做连续多期官方对账，确认来源稳定性、许可和附加号语义；
2. 明确福建31选7 / 任选2–5的正式判奖规则，再建设独立 judge 层；
3. 版主赔率范围、赔率快照与风险引擎；
4. 管理后台与开奖人工复核操作界面；
5. PostgreSQL 迁移；
6. Android 联机真机主链路验收与生产 HTTPS API；
7. iOS 原生工程、签名与 TestFlight；
8. 正式结果更正/撤销的显式审计流程。

在开奖规则和连续对账完成前，不启用第三方数据自动确认、自动判奖或自动派奖。

## 文档入口

- 架构：`docs/ARCHITECTURE.md`
- 领域模型：`docs/DOMAIN_MODEL.md`
- API Contract：`docs/API_CONTRACT.md`
- 开奖数据源：`docs/DRAW_DATA_SOURCES.md`
- 开奖采集/确认边界：`docs/DRAW_INGESTION.md`
- 首页数据：`docs/HOME_BANNER.md`
- 路线图：`docs/ROADMAP.md`
- 待办：`docs/BACKLOG.md`

主要页面仍以横屏为第一验收方向；当前不全局锁定屏幕方向。
