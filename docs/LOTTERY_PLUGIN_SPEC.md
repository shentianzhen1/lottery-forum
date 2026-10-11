# 玩法插件规格

状态：规划。当前代码内注册：数字选号、排名竞猜、福建31选7，以及福建31任选 2/3/4/5。

## 插件必须提供

- `game_id`、名称、类型、`schema_version`、`rule_version`、`enabled`。
- `validate(payload)`：只校验和归一化输入，不改钱包。
- `stake_enabled`：未启用时不能扣分。
- 渲染器标识。V0.1 允许客户端按类型选择固定组件，没有独立渲染器注册表。

## V0.1 示例

- DemoDigit：`number-pick`，三个不重复数字。
- DemoRanking：`ranking-pick`，三个不重复选项。
- DemoPick：`fujian-31`，七个 1 到 31 的不重复号码，返回 21 对（选7；id 不动）。
- 福建31任选：`fujian-31-any-2` … `fujian-31-any-5`，从 1–31 选对应个数、不重复；`pair_count` = C(n,2)。期号彩种仍挂 `fujian-31`，投注时带具体玩法 id。

示例不能绕过钱包、期号和投注对象。`fujian-31` 与任选 2–5 均已 `stake_enabled`，可走 `POST /bets` 冻结占位（固定 10 积分；派奖跟现网连本带利共 2 倍）。

## 尚未实现

没有独立的 LotteryDefinition、SettlementRuleRegistry，也不能只上传插件包就接入新玩法。结算规则接入前，`settles_points` 必须保持 false。
