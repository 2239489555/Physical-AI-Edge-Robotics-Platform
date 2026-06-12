# 开发任务索引

这些 Markdown issue 是从 PRD 拆分出来的详细开发执行队列，也是当前本地任务事实源。只有在任务经过审查、脱敏并确认适合公开后，才发布到 GitHub Issues。

每个本地任务的默认 triage 标签：`needs-triage`。

任务类型说明：

- `AFK`：Agent 可以按任务说明独立执行、验证和交付。
- `HITL`：需要人参与判断、运行实机验证、确认技术选择或整理最终叙事。

## P0 - Edge Robotics Reliability Lab 主线

| ID | 标题 | 类型 | 依赖 |
| --- | --- | --- | --- |
| P0-001 | 仓库骨架与运行产物治理 | AFK | 无 |
| P0-002 | 系统基线采集器与变更账本 | AFK | P0-001 |
| P0-003 | ROS 2 workspace 初始化与最小 C++ 闭环（已完成） | AFK | P0-001 |
| P0-004 | 机器人零基础上手指南与命令证据（文档完成，待复述） | HITL | P0-003 |
| P0-005 | Edge reliability 消息定义与接口契约（已完成） | AFK | P0-003 |
| P0-006 | 100Hz fake sensor publisher 垂直切片（已完成） | AFK | P0-005 |
| P0-007 | Processor metrics subscriber 垂直切片（已完成） | AFK | P0-006 |
| P0-008 | rosbag 录制与回放工作流（已完成） | AFK | P0-007 |
| P0-009 | 丢帧与 subscriber delay 故障注入（已完成） | AFK | P0-007 |
| P0-010 | 可配置阈值的 health monitor（已完成） | AFK | P0-009 |
| P0-011 | tegrastats 解析器与 ROS 2 system metrics node（已完成） | AFK | P0-002, P0-003 |
| P0-012 | Jetson 指标接入 system health（已完成） | AFK | P0-010, P0-011 |
| P0-013 | QoS 实验 runner 与 100/200Hz 报告（实现已准备，待 Jetson smoke） | AFK | P0-012 |
| P0-014 | 500/1000Hz 压力实验与瓶颈报告 | AFK | P0-013 |
| P0-015 | 项目内 start/stop runtime 脚本 | AFK | P0-012 |
| P0-016 | health_check 与 collect_logs 诊断包 | AFK | P0-015 |
| P0-017 | cleanup_artifacts 与 rollback 文档 | AFK | P0-016 |
| P0-018 | P0 10 分钟 gate 证据包 | HITL | P0-014, P0-017 |
| P0-019 | P0 面试故事库与 Demo 大纲 | HITL | P0-018 |

## P0.5 - 展示增强

| ID | 标题 | 类型 | 依赖 |
| --- | --- | --- | --- |
| P0.5-001 | 轻量 dashboard 的 metrics export 数据源 | AFK | P0-016 |
| P0.5-002 | P0 metrics 的 localhost HTML dashboard | AFK | P0.5-001 |

## P1 - 第一批增强能力

| ID | 标题 | 类型 | 依赖 |
| --- | --- | --- | --- |
| P1-001 | 公开数据集或 rosbag 选型 manifest | HITL | P0-018 |
| P1-002 | video file camera adapter 垂直切片 | AFK | P1-001 |
| P1-003 | TensorRT 环境预检与模型选择 | HITL | P0-018 |
| P1-004 | TensorRT inference node 垂直切片 | AFK | P1-003 |
| P1-005 | TensorRT 性能报告与面试素材 | AFK | P1-004 |
| P1-006 | Nav2 与 TurtleBot3 可行性 spike | AFK | P0-018 |
| P1-007 | 第一个 Nav2 故障复现报告 | AFK | P1-006 |

## P2 - NVIDIA 生态探索

| ID | 标题 | 类型 | 依赖 |
| --- | --- | --- | --- |
| P2-001 | Isaac ROS 3.2 兼容性 spike | AFK | P0-018 |
| P2-002 | Isaac ROS 轻量加速对比 | AFK | P2-001 |

## Capstone - 最终作品化

| ID | 标题 | 类型 | 依赖 |
| --- | --- | --- | --- |
| CAP-001 | Capstone Demo、简历总结与最终故事线 | HITL | P0-019，以及至少一个 P1 增强任务 |
