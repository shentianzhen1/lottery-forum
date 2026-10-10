# 彩票论坛

横屏优先的多玩法基础平台。积分账本可追溯，不含现金充值、提现或兑付。

本仓库与 `shentianzhen1/lottery` 无关。不迁入该旧仓的投注、充值、提现或代理开户实现。

## 当前状态

积分不能提现或转账，但可以用于玩法赔付和申请版主。边界见 `docs/decisions/2026-10-10-points-boundary.md`。

已实现：

- `GET /health`
- 积分钱包写入 SQLite 文件，重启后余额仍在。PostgreSQL 迁移尚未执行
- 福建31选7 可保存校验后的选号记录。重复幂等键不新增。不扣分、不开奖、不派奖
- 可用积分达到默认 10000 即可开通版主版块，不需要批准。开通会冻结门槛积分。赔付公式未定
- 玩法中心横屏骨架：左侧玩法，右侧输入区和结果区
- 首页有平台公告栏。没有数据时显示暂无公告，接口尚未接入
- 宽度低于 960 时提示使用横屏，不把窄屏页伪装成横屏首页
- CI 工作流已添加；是否通过以 GitHub Actions 实际结果为准

未实现：

- PostgreSQL 尚未连接。当前持久化是 SQLite 文件
- 积分中心页面尚未请求接口
- 玩法派奖
- 版主申请审核
- 管理后台
- Android 测试包
- 真机或模拟器横屏验收

## 本地运行

```bash
python -m pip install -r apps/api/requirements.txt
cd apps/api && python -m pytest tests
cd apps/mobile && flutter pub get && flutter analyze && flutter test
uvicorn app.main:app --app-dir apps/api --reload
```

不全局锁定屏幕方向。主要页面仍以 16:9 横屏为第一验收方向。
