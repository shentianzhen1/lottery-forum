# 开奖数据采集与人工确认边界

开奖域分成两层：

1. **observation 证据层**：保存外部或人工获得的原始开奖观察，允许同一期保留多个更正版本；
2. **result 确认层**：管理员人工复核后，从某一条 observation 生成不可静默覆盖的正式开奖结果快照。

两层目前都与期号状态、判奖和积分结算解耦。

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

- 自动调用任何第三方开奖 API；
- 自动把外部期号映射为本系统期号；
- 因 observation 自动生成 confirmed result；
- 修改 `rounds` 期号状态；
- 生成 `WIN / LOSS / VOID` 判奖结果；
- 调用 settlement；
- 冻结、扣除、增加或派奖任何积分；
- 因“最新 observation”自动覆盖历史版本或已确认 result。

正式接入自动来源前仍需完成来源授权/稳定性确认和连续多期人工对账。后续判奖层只能读取明确确认后的 result，并继续与资金结算保持独立事务边界。
