# BarkAgent Phase 2 手动测试执行报告

> 执行人: ____ | 日期: ____ | Xcode: ____ | iOS Sim: ____
> 关联计划: `doc/phase2-manual-test-plan.md`

## 自动化基线

| 包 | 结果 | 时间戳 |
|---|---|---|
| Models | __/11 | |
| BarkService | __/63 | |

阻塞? ⬜ 是 / ⬜ 否

---

## L0 工程基线

| 用例 | 结果 | 备注 |
|---|---|---|
| L0-1 编译 | ⬜ pass / ⬜ fail | |
| L0-2 启动 | ⬜ pass / ⬜ fail | 冷启动 ___ ms |
| L0-3 四 target | ⬜ pass / ⬜ fail | |
| L0-4 App Group | ⬜ pass / ⬜ fail | |
| L0-5 Keychain | ⬜ pass / ⬜ fail | |

## L1 5 Tab 走查

| 用例 | iPhone SE | 15 Pro | 15 Pro Max | 截图 |
|---|---|---|---|---|
| L1-1 Tab 数 | ⬜ | ⬜ | ⬜ | |
| L1-2 选中态 | ⬜ | ⬜ | ⬜ | |
| L1-3 SE 不溢出 | ⬜ | — | — | |
| L1-4 FAB 移除 | ⬜ | ⬜ | ⬜ | |
| L1-5 Memo 入口 | ⬜ | ⬜ | ⬜ | |
| L1-6 ItemTimelineView 已删 | ⬜ | — | — | |

## L2 Mock 契约对齐

| 屏 | 结果 | 偏差列表 | 截图 |
|---|---|---|---|
| L2-A Dashboard | ⬜ | | |
| L2-B Detail | ⬜ | | |
| L2-C Setup | ⬜ | | |
| L2-D History | ⬜ | | |
| L2-E Search | ⬜ | | |
| L2-F Settings | ⬜ | | |
| L2-G 字体降级 | ⬜ | | |

## L3 DesignSystem 高风险组件矩阵

| 组件 | 用例数 | 通过 | 截图归档 |
|---|---|---|---|
| AgentHeroCard | 6 | __/6 | |
| AgentTaskCard | 6 | __/6 | |
| DetailHero | 6 | __/6 | |
| SummaryPanel | 6 | __/6 | |
| StepRow | 6 | __/6 | |
| curl 模板卡 | 4 | __/4 | |

## L4 业务逻辑

路径: ⬜ A (Demo push wiring 完成) / ⬜ B (单测代替)

| 用例 | 结果 | 备注 |
|---|---|---|
| L4-1 聚合 | ⬜ pass / ⬜ skip-B | |
| L4-2 旧协议 | ⬜ pass / ⬜ skip-B | |
| L4-3 状态机 | ⬜ pass / ⬜ skip-B | |
| L4-4 progress | ⬜ pass / ⬜ skip-B | |
| L4-5 stale | ⬜ pass / ⬜ fail | |
| L4-6 context menu | ⬜ pass / ⬜ fail | |
| L4-7 History 混合源 | ⬜ pass / ⬜ fail | |

## L6 缺口登记

| 缺口 | 跳过原因 | 计划回归阶段 |
|---|---|---|
| APNs 注册 | Phase 2.1/2.2 ⏳ | Phase 4.0 |
| NSE 推送 | Phase 2.3 ⏳ | Phase 2 收尾 |
| 解密推送 | Phase 2.4 ⏳ | Phase 2 收尾 |
| Darwin 通知 | Phase 2.9/2.13 ⏳ | Phase 2 收尾 |
| Enrich/Present | Phase 2.10/2.11 ⏳ | Phase 2 收尾 |
| curl 真实注入 | Phase 4.13 ⏳ | Phase 4 |

## 阻塞 / 风险

- (列出执行中发现的新问题)

## 结论

⬜ 通过本轮验收 / ⬜ 退回修复（列出阻塞用例）
