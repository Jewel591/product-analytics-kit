---
name: integrate-productanalyticskit
description: 审查或维护已暂停的 ProductAnalyticsKit 仓库时使用；不得用它新增消费端或把 Apple App 迁入本包。
---

# ProductAnalyticsKit 已暂停

ProductAnalyticsKit 只保留源码与历史。不得新增消费端、发布版本、把 Apple App
迁入本包，或与官方 PostHog SDK 直连并行投递。

Apple App 产品分析工作使用 Tukey 的 `integrate-app-posthog` skill，直接接入官方
PostHog SDK，并继续遵守有界事件合同、身份 reset、敏感字段禁入、关闭自动采集与
投递不得阻塞产品行为等边界。

只有 Ivens 明确决定恢复本 Kit 后，才可继续实现或迁移消费端。维持暂停状态所需的
仓库维护仍按正常 issue 与 PR 流程进行。
