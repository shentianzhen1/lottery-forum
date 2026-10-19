# 彩票论坛：框架审计与首轮修复

日期：2026-10-19。审计基线为 main `2a7213833ab371cac8de8075f19d90a20592b562`。
这是源码、开放 PR 和测试审计，不是生产安全认证、压测或真机验收。未合并任何 PR，未访问或改写实际用户数据库。

## 结论与架构取舍

保留 Flutter + FastAPI 模块化单体，不拆微服务、不重写客户端、不增加 Redis。
当前最先需要收口的是跨模块命令的事务边界，而不是继续堆玩法。
SQLite 仍是当前实现；PostgreSQL 必须在存储契约与迁移测试齐全后接入，不能拿旧 PR 当作可直接替换的后端。

## 核对的远端状态

| PR | 基线核对的 HEAD | 状态与处理建议 |
| --- | --- | --- |
| #10 PostgreSQL 钱包 | `28cba7d` | Open。旧 AppState 只有 auth/ledger/games/participation；PostgresLedgerStore 未提供当前账本所需的 locked/冻结接口，账号 session 接口也落后。不可直接合并，需重新适配与数据库集成测试。 |
| #65 公告详情客户端 | `f4f91d6` | Open，CI 成功；未进入 main。源码仍缺异步请求版本校验，不能据 CI 断言请求竞争已覆盖。 |
| #66 文档同步 | `8b8bd63` | Open，CI 成功；与 #67/#68 的 Android 文档有交叉，合入时不能恢复过期地址/构建描述。 |
| #67 API 地址配置 | `1decf98` | Open，CI 成功；地址配置不等于设备网络验收。 |
| #68 Android debug 构建 | `ca972fc` | Open + Draft，基于 #67；API/Flutter CI 与真实 APK 构建均成功（run `38868158322`）。未完成安装、联网、手机横屏验收。 |

核对时 main 未更新，未发现 AGENTS.md。main 分支的 protected 字段为 false；本轮不修改仓库保护规则。

## 模块现状

| 模块 | 已有 | 主要边界/缺口 |
| --- | --- | --- |
| 账号与权限 | scrypt 密码、哈希 session、24 小时有效期、管理员/版块归属校验 | 注册与发积分非同一命令事务；登录限流无冷却/清理机制；管理员用户名须可信预置 |
| 钱包账本 | 分录、余额投影、冻结、幂等、等额反向纠错 | 单步账本安全不等于跨模块命令原子性；查询余额/冻结无统一读快照 |
| 玩法插件 | GameSpec、输入校验、7个内置玩法 | 无明确玩法→彩种绑定；无可注入的插件列表或独立判奖注册表 |
| 期号/投注/结算 | OPEN 投注、取消、管理员记录结果、WIN/LOSS/VOID、固定2倍快照 | 未存真实开奖号码/自动判奖；缺快照严格校验；本轮修复事务一致性 |
| 版主/风控 | 达标开通、冻结门槛、版块归属 | 开通与冻结仍分步；自定义赔率/风险引擎未实现，不自动定义赔付上限 |
| Flutter | 横屏页面、注册/投注/取消、积分显示 | 960逻辑像素门槛；固定列宽；请求超时/网络错误/请求竞争/提交重试幂等不足 |
| 构建与存储 | main 有API/Flutter测试；#68已实际出APK | main未包含#67/#68；SQLite初始化DDL和迁移并存，无统一迁移版本管理；未做生产备份恢复演练 |

## 风险清单（按下一步优先级）

P1 表示应在扩大测试或公开部署前解决；P2 表示体验、维护性或需要补验证的风险。

| 编号 | 级别 | 证据与影响 | 本轮处理 |
| --- | --- | --- | --- |
| TX-01 | P1 | BetService.place 先提交冻结再提交单据；cancel先提交状态再解冻；SettlementService逐笔/逐分录提交。故障可留下已提交前缀。原有123项测试通过，但新加6项故障注入全部失败。 | 已实现本分支修复；仍待PR审查/合入。 |
| DOMAIN-01 | P1 | GameSpec无lottery_id；BetService未核对期号彩种。隔离数据库实测：number-pick可在fujian-31期号被ACCEPTED。会导致玩法与版块赔付归属不一致。 | 未修：下一独立目标，在插件元数据定义归属并在冻结前拒绝跨彩种请求。 |
| TX-02 | P1 | AuthService.create_account先写账号再发积分；ModeratorService.open_board先冻结再写版块。仍可能失败半完成或并发报唯一键错误。 | 未修；不要把TX-01修复描述成所有写操作均原子化。 |
| AUTH-01 | P1 | AuthService.failures按用户名计数，第5次后无过期/冷却，也无法通过正确密码恢复；重启又会清空。resolve_role按环境中的用户名授管理员，新注册同名也会生效。 | 未修；限流需有界且可恢复；公开注册前应可信预置管理员，并防止保留名被抢注。 |
| UI-01 | P1 | ApiClient未设超时，gateway仅捕获ApiException；placeBet/cancelBet遇网络/JSON异常可逃出UI且busy状态不清。每次提交重新生成幂等键，响应丢失后重试有重复冻结风险。 | 未修；统一网络错误与finally，保存一次操作的幂等键，不盲目自动重发写请求。 |
| UI-02 | P2 | _refreshRound/_refreshCancellableBets与#65详情_load只有mounted检查，没有请求代次/资源id检查。旧请求可能覆盖新玩法/新公告状态。 | 静态发现，未做Flutter竞争回归；修复需可控Completer测试。 |
| LIFE-01 | P2 | create_app()中build_state一次，lifespan开始又build_state一次，结束无connection.close。 | 未修；集中应用生命周期初始化/释放，保留测试可注入入口。 |
| STORAGE-01 | P2 | 列表与账本分页多为先全量读取再切片；各Store构造执行DDL，迁移无版本表。LedgerStore Protocol缺当前frozen/hold等完整契约。 | 未修；先统一存储协议和迁移版本，再接PostgreSQL。 |
| SETTLE-01 | P2 | _win_payout对坏JSON/不合法倍率回退2倍，int转换可能截断小数。当前HTTP不允许玩家写快照，但未来赔率配置/历史迁移接入后会放大风险。 | 未修；下一阶段需严格快照校验并fail closed，不猜测历史赔率。 |
| DEVICE-01 | P2 | 960逻辑像素与280/320固定列宽可能挡住手机横屏。#68出包只证明编译成功。 | 不直接降阈值；按真实逻辑宽高补布局测试和设备验收。 |

补充：`GET /settlements/{round_id}`目前任何登录者可读整期投注id/结果；应明确公开结果与私人投注明细的边界，再制定过滤契约。`/games/{id}/entries`是文档公开的临时直接扣分接口，并非完整投注链；建议退出兼容期时单独下线，不能让新客户端继续依赖。

## 本轮框架修复：SQLite 命令事务

- `app.db.AtomicConnection`：统一连接锁；独立语句使用autocommit，多步命令显式`atomic()`；外层`BEGIN IMMEDIATE`负责提交，嵌套使用SAVEPOINT。
- Store既有`commit()`在命令内不再提前提交；异常回滚完整命令。DDL脚本禁止在命令内运行，避免executescript隐式提交。
- 账本`locked()`复用同一连接事务，不再先提交调用者的未完成写入；取消旧的独立线程锁/线程局部提交标记。
- 命令边界覆盖：投注place/cancel、结算record/finalize、期号推进。BetService/SettlementService构造时拒绝分散连接，不能假装跨数据库原子化。
- 不改变赔率、固定注额、权限、接口响应和表结构；不修复历史坏账，不执行数据迁移。
- 连接只能由`app.db.connect()`创建；显式事务应使用`atomic()`，不能用sqlite原生`with connection`或直接操作cursor来绕过命令边界。未来PostgreSQL应实现独立UoW契约，不能复用SQLite连接类。

这仍不是生产级并发容量承诺：写入会串行化，busy_timeout仍为5秒；注册、版主开通和读取一致性缺口如上列出。

## 验证证据

1. 基线：`cd apps/api && python -m pytest tests -q` → 123 passed。
2. 修复前新增6项故障注入 → 6 failed，覆盖投注写入、取消解冻、批量记录以及WIN/LOSS/VOID整期finalize。
3. 修复后新增测试覆盖：异常后整库快照不变、重试与重复finalize、外层回滚不被账本commit穿透、嵌套SAVEPOINT、同连接/独立连接并发不超支、同键只建一单、并发取消只成功一次、重开数据库无孤立冻结、拒绝混合连接。
4. 修复后本地全量：137 passed（含新增14项），1条Starlette/anyio依赖弃用警告；`compileall`、`git diff --check`、`pip check`通过。PR CI结果另见PR运行日志；这不是依赖漏洞扫描，未执行外部漏洞数据库审计。
5. 本环境未安装Flutter/Android SDK，未本地复跑Flutter、构建APK或做设备验收。此分支只改后端与审计文档，不包含#65–68。

## 后续顺序（每次一个可验收目标）

1. 审查本轮事务修复；扩展到注册/版主开通，补故障回滚与重试证据。
2. 插件元数据增加明确彩种归属，拒绝跨彩种投注；统一幂等载荷冲突约定。
3. 客户端网络/提交幂等/异步竞争回归，然后手机横屏布局验收。
4. 存储Protocol、应用生命周期、版本化迁移收口后，重新整理#10并跑真实PostgreSQL集成测试。

不把后台、风控、真实开奖、复杂赔率一次性塞入同一个PR；不因CI绿色宣称正式上线就绪。

后续分支进度：TX-02的注册/版主开通事务已在独立关联变更中补齐，详见
[账号与版主事务补齐](2026-10-19-account-moderator-transactions.md)。上面的风险表保留首轮审计时点，不表示后续PR已合并main。
