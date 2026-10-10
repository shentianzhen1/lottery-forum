# 风控引擎

状态：只有接口边界，没有阈值。

## 接口

- `RiskCalculator.evaluate(candidate, exposure, rules)` 返回 RiskSnapshot。
- `can_accept(snapshot)` 决定是否接单。
- 快照必须保存评估时间、输入摘要、规则版本和决定。

## 约束

不能用占位数字当作正式阈值。拒绝接单不能扣分。通过风控后仍要走钱包冻结，不能由风控直接改余额。
