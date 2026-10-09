# 彩票论坛

横屏优先的多玩法基础平台。积分账本可追溯，不含现金充值、提现或兑付。

本仓库与 `shentianzhen1/lottery` 无关。不迁入该旧仓的投注、充值、提现或代理开户实现。

## 当前状态

M1 骨架已开始，未完成。

已实现：

- `GET /health`
- 注册、登录和本人积分查询。新账户余额为 0
- 两个示例玩法的输入校验。校验不结算积分
- 玩法中心横屏骨架：左侧玩法，右侧输入区和结果区
- Flutter 横屏首页骨架：左导航、中部玩法入口、右侧积分与申请版主
- 宽度低于 960 时提示使用横屏，不把窄屏页伪装成横屏首页
- CI 工作流已添加；是否通过以 GitHub Actions 实际结果为准

未实现：

- 持久化数据库连接。当前账户和账本只在进程内 SQLite 中
- 玩法结算接入积分账本
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
