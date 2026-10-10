# 玩法插件规格

状态：规划。当前只有代码内注册的三个示例。

## 插件必须提供

- `game_id`、名称、类型、`schema_version`、`rule_version`、`enabled`。
- `validate(payload)`：只校验和归一化输入，不改钱包。
- `stake_enabled`：未启用时不能扣分。
- 渲染器标识。V0.1 允许客户端按类型选择固定组件，没有独立渲染器注册表。

## V0.1 示例

- DemoDigit：`number-pick`，三个不重复数字。
- DemoRanking：`ranking-pick`，三个不重复选项。
- DemoPick：`fujian-31`，七个 1 到 31 的不重复号码，返回 21 对。

示例不能绕过钱包、期号和投注对象。`fujian-31` 当前不走临时固定 10 积分扣分。

## 尚未实现

没有独立的 LotteryDefinition、SettlementRuleRegistry，也不能只上传插件包就接入新玩法。结算规则接入前，`settles_points` 必须保持 false。
