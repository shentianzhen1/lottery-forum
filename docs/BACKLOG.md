# 待办 / Backlog

只登记范围外事项，本文不实现功能。与 `docs/ROADMAP.md` 近期顺序互补。

## 文案与产品体验

- **未开售 vs 已截止拆文案**：当前 `UPCOMING`（未开售）投注失败也走 `ROUND_CLOSED`「当期已截止，无法投注」。宜拆独立错误码/文案（如「当期未开售」）。
- **公告详情 / 「更多」**：首页公告不可点进详情；无完整列表页。
- **横幅点击跳转**：横幅本片不点跳；站内玩法/公告跳转为产品愿望。

## 玩法与投注

- ~~**福建 31 选 7 接投注骨架**~~：已放开 `stake_enabled`，与数字选号同款 `POST /bets` 冻结占位（本片不派奖）。客户端横屏选号已接投注（#47）。
- ~~**福建 31 任选 2/3/4/5（后端）**~~：已注册 `fujian-31-any-2`…`any-5`，与选7共用期号彩种 `fujian-31`；同款冻结 + 连本带利共 2 倍。客户端入口另片。
- **取消投注**：`POST /bets/{bet_id}/cancel`（仅 `OPEN` 期内、未锁定）未开放。
- ~~**期号推进到 SETTLING + Settlement 骨架**~~：已开放 `CLOSED`→`DRAWN`→`SETTLING` 与 `WIN`/`LOSS`/`VOID` 记录；本片不派奖。
- ~~**结算权限收口（管理员）**~~：期号创建/推进与写结算已限 `role=admin`，越权 403 `FORBIDDEN`；管理员来自 `LOTTERY_FORUM_ADMIN_USERNAMES` 或本地种子，注册不能自封。
- ~~**版主归属期号与权限**~~：期号挂 `board_id`（归属开设该版块的版主，彩种须一致）；该版块版主可建号并推进自己版块的期号，旧期号（无 `board_id`）仅管理员；写结算仍只限管理员（版主是赔付方）；管理员保留全部权限。本地造版主用 `LOTTERY_FORUM_DEV_SEED_MODERATORS` 启动种子（默认关闭）；本地造 OPEN 期用 `LOTTERY_FORUM_DEV_SEED_OPEN_ROUNDS`（默认关闭）。
- **版主写结算 / 结算复核**：如需让版主参与结算，须有独立复核（版主是赔付方，不能自判）；当前不做。
- ~~**派奖第一刀（VOID/LOSS → SETTLED）**~~：已开放管理员 `POST /rounds/{id}/settled`；`VOID` 解冻退回、`LOSS` 划入版主钱包。
- ~~**WIN 派奖最小可跑版（固定 2 倍）**~~：`odds_snapshot` 写 `{"status":"fixed","multiplier":2}`；finalize 时 `WIN` 解冻后从版主可用付盈利 `stake×(倍率−1)`（连本带利共倍率倍）；不足整期挡 `INSUFFICIENT_MODERATOR_POINTS`；判断可用不算同批 LOSS；门槛冻结池不动。
- **`payout_formula` 配置位与快照对齐**：版块字段仍可显示 `unset`，实结算看投注 `odds_snapshot`；若要对齐配置位另开。
- **阶梯/复杂赔率与冻结池扣付**：本片仅固定倍率 2（连本带利）；从开通门槛冻结池扣付未做。

## 基础设施

- **PostgreSQL**：当前 SQLite 文件持久化；有实际数据库服务后再迁。
