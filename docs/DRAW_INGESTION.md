# 开奖数据采集与人工确认边界

开奖域分成三层：

1. **provider 采集层**：只读调用外部来源，把响应转换为本系统 observation 输入；
2. **observation 证据层**：保存外部或人工获得的原始开奖观察，允许同一期保留多个更正版本；
3. **result 确认层**：管理员人工复核后，从某一条 observation 生成不可静默覆盖的正式开奖结果快照。

三层目前都与期号状态、判奖和积分结算解耦。

## Provider 采集

当前首个适配器为 `huiniao`，仅支持福建31选7 `fujian-31`。

管理员手动触发接口：

- `POST /api/v1/draws/providers/huiniao/pull?limit=5`

边界：

- `limit` 只允许 `1..20`；
- 外部请求使用 HTTPS，并设置短超时；
- HTTP 失败、坏 JSON、业务错误码、字段结构变化都会使本次采集失败，不会静默吞掉；
- 读取 `one..seven` 为 7 个基本号；`eight` 如存在只作为附加号码保存，不解释业务含义；
- 保存每期开奖记录的原始 provider row 到 `raw_payload`；
- provider 只把数据写成 `PENDING_REVIEW` observation，不自动调用 result confirm；
- provider 不修改 rounds、不判奖、不调用 settlement、不冻结/扣除/增加任何积分；
- 当前没有定时任务，必须由管理员显式触发采集。

### 外部期号规范化

Huiniao 已观察到 `YYNNN` 与 `YYYYNNN` 两种期号形态，因此禁止无条件补年份，也禁止根据 `next_code` 猜当前期号。

当前适配规则只有两种：

- 来源已经返回 `YYYYNNN`，且前四位与 `draw_date` 年份一致：直接采用；
- 来源返回 `YYNNN`，且前两位与 `draw_date` 年份后两位一致：使用 `draw_date` 的完整年份生成 `YYYYNNN`。

其他形态或年份不一致一律返回 `DRAW_PROVIDER_ISSUE_CODE_INVALID`，不写 observation，等待人工核查来源变化。

## 开奖观察 observation

管理员接口：

- `POST /api/v1/draws/observations`
- `GET /api/v1/draws/observations`

写入字段：

- `provider`：来源标识
- `lottery_id`：彩种
- `raw_code`：来源原始期号
- `normalized_code`：本系统规范期号
- `draw_date`：开奖日期（`YYYY-MM-DD`）
- `main_numbers`：基本号码
- `extra_numbers`：附加号码；当前仅保存，不解释业务含义
- `raw_payload`：原始响应/人工录入的原始对象

系统生成：

- `content_hash`：规范化内容 SHA-256
- `fetched_at`：服务器记录时间
- `version`：同来源、同彩种、同规范期号的内容版本
- `status=PENDING_REVIEW`

### 幂等与更正

- 同一 `provider + lottery_id + normalized_code + content_hash` 重复提交，返回原 observation，不重复落库。
- 同一来源、同一彩种、同一期号出现不同内容时，不覆盖旧记录；新内容写为 `version + 1`。
- observation 内容和版本保留为来源证据。即使某条 observation 后续被选作正式结果，其 observation 状态也不被改写；“已确认”由独立 result 快照表达。

## 人工确认 result

管理员接口：

- `POST /api/v1/draws/observations/{observation_id}/confirm`
- `GET /api/v1/draws/results`

确认时系统复制 observation 的来源、期号、开奖日期、号码、内容哈希和来源版本，并记录：

- `result_id`
- `source_version`
- `confirmed_by`
- `confirmed_at`
- `status=CONFIRMED`

### 确认约束

- 同一 observation 重复确认幂等返回原 result。
- 同一 `lottery_id + normalized_code` 只能有一个已确认 result。
- 如果一期已经确认，再尝试确认另一个 observation 版本，返回冲突，不会覆盖原正式结果。
- 当前**没有**正式结果撤销/替换流程。未来若需要处理官方更正，必须新增显式、可审计的 supersede/revoke 流程，不能直接 UPDATE 覆盖。

## 当前号码校验

目前只开放 `fujian-31` observation：

- 基本号必须 7 个；
- 基本号必须互异；
- 基本号范围 `1..31`；
- 附加号码如存在，也必须为 `1..31` 且自身不重复。

附加号码与基本号之间的业务关系暂不硬编码；在官方规则/来源字段语义确认前，仅作为来源信息保存。

## 明确未实现

当前开奖模块**不会**：

- 定时/无人值守调用第三方开奖 API；
- 在无法由开奖日期校验的情况下猜测外部期号；
- 因 provider pull 或 observation 自动生成 confirmed result；
- 修改 `rounds` 期号状态；
- 生成 `WIN / LOSS / VOID` 判奖结果；
- 调用 settlement；
- 冻结、扣除、增加或派奖任何积分；
- 因“最新 observation”自动覆盖历史版本或已确认 result。

正式进入自动化采集前仍需完成来源授权/稳定性确认和连续多期人工对账。后续判奖层只能读取明确确认后的 result，并继续与积分结算保持独立事务边界。
