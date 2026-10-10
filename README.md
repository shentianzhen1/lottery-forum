# 彩票论坛

横屏优先的多玩法基础平台。积分账本可追溯，不含现金充值、提现或兑付。

本仓库与 `shentianzhen1/lottery` 无关。不迁入该旧仓的投注、充值、提现或代理开户实现。

## 当前状态

版主申请不需要批准。可用积分达到后台门槛即可开通，默认 10000。见 `docs/decisions/2026-10-10-moderator-self-serve.md`。

积分不能提现或转账，但可以用于玩法赔付和申请版主。边界见 `docs/decisions/2026-10-10-points-boundary.md`。

框架文档见 `docs/ARCHITECTURE.md`、`docs/DOMAIN_MODEL.md`、`docs/API_CONTRACT.md`。首页横幅和公告见 `docs/HOME_BANNER.md`，页面尚未实现。

已实现：

- `GET /health`
- 积分钱包写入 SQLite 文件，重启后余额仍在。PostgreSQL 迁移尚未执行
- 福建31选7 可保存校验后的选号记录。重复幂等键不新增。不扣分、不开奖、不派奖
- 可用积分达到默认 10000 即可开通版主版块，不需要批准。开通会冻结门槛积分。赔付公式未定
- 玩法中心横屏骨架：左侧玩法，右侧输入区和结果区
- 首页有平台公告栏。没有数据时显示暂无公告，接口尚未接入
- 宽度低于 960 时提示使用横屏，不把窄屏页伪装成横屏首页
- CI 工作流已添加；是否通过以 GitHub Actions 实际结果为准
- 个人中心可注册、登录和退出。注册发放 100 开户积分

未实现：

- PostgreSQL 尚未连接。当前持久化是 SQLite 文件
- 玩法派奖
- 版主自助开通与坐庄引擎（门槛开通已定，实现未落地）
- 管理后台
- Android 平台文件已生成，测试包默认横屏。本环境没有 Android SDK，APK 尚未生成。见 `docs/ANDROID_TEST_BUILD.md`
- 真机或模拟器横屏验收

## 本地运行

```bash
python -m pip install -r apps/api/requirements-dev.txt
cd apps/api && python -m pytest tests
cd apps/mobile && flutter pub get && flutter analyze && flutter test
uvicorn app.main:app --app-dir apps/api --reload
```

不全局锁定屏幕方向。主要页面仍以 16:9 横屏为第一验收方向。
