# M0 审计与本轮推进

审计时间：2026-10-09。证据来自仓库 `shentianzhen1/lottery-forum`。

## 现状

- 公开仓，默认分支 `main`。审计时 `main` 为 `e383d539`，只有 README。
- 分支 `docs/project-plan-horizontal-first` 含 `docs/PROJECT_PLAN.md` 与 `docs/DEVELOPMENT_HANDOFF.md`。对应草稿 PR #1，未合并。
- 无客户端、后端、数据库、插件、积分账本、版主中心、后台或 CI。
- 无横屏页面可验收。
- 旧仓 `shentianzhen1/lottery` 不是本项目基线，不迁入充值、提现或投注实现。

## 本轮实际推进

只建立 M1 的可运行边界：

- FastAPI `/health`，以及用户、积分、版主申请的 501 边界。
- Flutter 横屏首页骨架。宽度不足 960 时不假装已完成横屏首页。
- 不锁定全局屏幕方向。
- 不实现玩法规则、账本记账、审核、现金充值、提现或用户间转账。

本环境没有 Flutter SDK，也没有 Android 模拟器。API 测试在本地运行；Flutter 测试交给 CI，未在本地执行，不得记为本地通过。
