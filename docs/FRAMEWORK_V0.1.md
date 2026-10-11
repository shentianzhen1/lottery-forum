# 彩票论坛 Framework V0.1

状态：与 main 对齐的框架边界。本文只记录模块和当前证据，不把未实现的模块写成已完成。

钱包、冻结、保证金、手续费和赔率快照都指平台积分，不是现金。当前不实现充值、提现、兑付或用户间转账。产品口径：该玩法下注由开设该玩法版块的版主承担赔付；本片 `WIN` 固定 2 倍从版主可用余额派奖，见 `docs/API_CONTRACT.md`。

## 1. 工程骨架

- Flutter Android：已有横屏骨架与玩法中心/版主开通等入口，没有 APK 二进制入库，真机未验。
- FastAPI：已有健康检查、账户、积分、玩法校验、期号、投注、结算骨架、版主开通。
- PostgreSQL：迁移文件已有。连接代码在未合并的 PR #10，本环境没有实际连上。
- Redis：未引入。只在缓存、限流或任务需求明确时再加。
- Docker：Compose 在 PR #10，本环境没有 Docker。
- GitHub Actions：已有 API 与 Flutter 检查。

## 2. 核心领域模型

- User：注册、登录和角色字段已有。`role=admin` 用于期号/结算写操作授权（来源：`LOTTERY_FORUM_ADMIN_USERNAMES` 或本地种子；注册一律 `user`）。版主不是角色，而是开设了某版块（`ModeratorBoard`）的账号。
- Wallet / Ledger：追加式积分账本、幂等和冻结已有。默认存储是 SQLite。
- Lottery：福建 31 选 7 等示例玩法已登记选号校验；没有独立彩种配置对象。
- Play：数字选号、排名竞猜和福建 31 选 7 是示例插件；`stake_enabled` 玩法可走投注冻结占位。
- Round：骨架已实现到 `SETTLED`。可创建/查询，单向推进 `UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`；可挂 `board_id`（彩种须与版块一致）。推进到结算中：管理员或该版块版主；进已结算仅管理员。无开奖号码落库。
- Bet：骨架已实现到 `ACCEPTED`，finalize 后 VOID/LOSS/WIN 进 `SETTLED`。挂 `OPEN` 期号，校验→记录→冻结占位（固定 10 积分）；`odds_snapshot` 为固定 2 倍。数字选号与福建 31 选 7 客户端已接投注；不取消。
- Settlement：已实现。`SETTLING` 期可落 `WIN`/`LOSS`/`VOID` 记录；`POST /rounds/{id}/settled` 对 VOID/LOSS/WIN 入账并进 `SETTLED`；版主可用不足整期挡。写结算与 finalize 仅管理员。
- ModeratorBoard：达标自助开通已实现（API + 客户端入口，无需人工审核）；门槛冻结已有。坐庄会话 / 赔付公式未实现。
- Risk：未实现。

## 3. 彩种扩展框架

已有玩法注册和输入校验。没有独立的彩种定义、渲染器注册表或结算规则注册表。新增玩法仍要改注册代码，不能只交插件包。

## 4. 通用钱包框架

已有余额投影、分录、冻结、解除冻结和幂等键。没有独立事务对象。版主开通门槛冻结已接入；LOSS 划入版主可用、WIN 从版主可用派奖（固定 2 倍）已开放；从门槛冻结池扣付未做。

## 5. 投注框架

已有校验、投注单记录、冻结占位与幂等。赔率快照与冻结分存（本片固定 2 倍）。生命周期做到 `ACCEPTED`，finalize 后 VOID/LOSS/WIN 进 `SETTLED`；取消与 `LOCKED` 未开放。

## 6. 期号框架

已实现到 `SETTLED`。状态机：`UPCOMING` → `OPEN` → `CLOSED` → `DRAWN` → `SETTLING` → `SETTLED`。关闭后不能新增投注。开奖号码落库未做；`WIN` 固定 2 倍派奖已开放。

## 7. 坐庄框架

未实现。预定包含坐庄会话、玩法、积分赔率快照、手续费策略、保证金和风险接口。版主达标开通与期号归属版块已落地；保证金数值与赔付公式未定，不得自行拍板。

## 8. 接口与测试

已有 API 契约（`docs/API_CONTRACT.md`）、领域模型与部分 API 测试和 CI。没有 PostgreSQL 集成测试执行记录或迁移实际执行记录。

## 当前顺序

对照 `docs/ROADMAP.md` / `docs/BACKLOG.md`：期号到 `SETTLED`（VOID/LOSS/WIN 固定 2 倍）、投注冻结占位、Settlement、结算权限与版主归属已进 main。下一步可做阶梯赔率/冻结池扣付等，不跳到现金投注或 Redis。PostgreSQL 有实际库服务后再接。
