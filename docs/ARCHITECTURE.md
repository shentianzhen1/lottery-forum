# 架构

状态：与 main 对齐的 Framework V0.1 边界。未实现的组件不能当成已部署。

## 分层

- Flutter Android 优先，iOS 只预留目录和响应式布局，不依赖 Android 专有接口。
- FastAPI 模块化单体提供 `/api/v1`。
- 领域模块按用户、钱包、彩种、玩法、期号、投注、结算、版主、风控和管理拆分。
- PostgreSQL 是目标数据库。当前默认存储是 SQLite 文件，连接代码尚未进入 `main`（见 PR #10）。
- Redis 和 WebSocket 未引入。只在缓存、限流或实时推送需求明确后加入。
- Docker Compose 和 GitHub Actions 用于本地依赖和 CI。本环境没有跑过 Docker。

## 横屏约束

主要页面以 16:9 横屏为第一设计目标。窄屏只提示使用横屏，不把竖屏页面拉宽后当作横屏完成。首页使用左导航、中部玩法和右侧积分面板。

## 当前实现边界

已有：健康检查、注册登录、积分账本与冻结、玩法校验、横屏骨架、首页横幅/公告只读、版主达标自助开通（含客户端入口）、期号状态机到 `SETTLED`（可挂 `board_id`；VOID/LOSS/WIN 入账）、投注骨架到 `ACCEPTED`（冻结占位、固定 2 倍快照；finalize 后 VOID/LOSS/WIN 进 `SETTLED`）、Settlement（落 `WIN`/`LOSS`/`VOID`，finalize 处理 VOID/LOSS/WIN）。

权限：管理员可创建/推进任意期号、写结算并 finalize 到 `SETTLED`；该版块版主可对本版块期号建号并推进到 `SETTLING`；写结算与进已结算仅管理员（版主是赔付方）。产品口径：下注由开设该版块的版主赔付；`LOSS` 注额划入版主可用；`WIN` 连本带利共 2 倍（版主付盈利）从版主可用派奖。

没有：阶梯赔率/冻结池扣付、坐庄引擎、管理后台、PostgreSQL 连接、真机横屏验收。细节以 `docs/API_CONTRACT.md`、`docs/DOMAIN_MODEL.md`、`docs/BACKLOG.md` 为准。

## SQLite 命令事务边界

注册（账号、开户积分、session）、单独创建账号与发积分、版主开通（门槛冻结、版块）、
投注创建/取消、结算批量记录/整期入账和期号推进使用同一连接的命令事务：
整个操作成功才提交，失败则同时回滚单据、冻结、分录和状态。账本内部操作使用嵌套
SAVEPOINT，不得提前提交外层命令。连接由 `app.db.connect()` 创建，多步写操作显式
使用 `atomic()`；独立SQL语句为autocommit。业务服务构造时校验关联Store共享连接，
不能用分散数据库连接冒充原子事务。

这不是所有写操作或所有后端的通用事务保证；这些命令的关联Store必须共享一个
`app.db.connect()`连接。新命令仍须明确边界并补回滚测试，不允许依赖某个Store隐式提交。
基于main的首轮修复与风险见 [2026-10-19框架审计](audits/2026-10-19-framework-audit.md)，
注册/版主开通的后续修复见 [账号与版主事务补齐](audits/2026-10-19-account-moderator-transactions.md)。
