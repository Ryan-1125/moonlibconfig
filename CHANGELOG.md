# Changelog

## 0.2.0 — 2026-10-22

- 新增列表/数组inserted、appended、removed_at，保留容器种类、顺序与原容器。
- 新增独立validate与ValidationIssue，聚合结构和资源问题并给出字段路径，不依赖序列化。
- 新增Document、SourcePosition、SourceLocation及带位置的文本/字节解析。
- 新增Document严格类型查询，类型不符时提供期望/实际类型、路径及原始值位置。
- 保持0.1.0公开API和语法策略，include继续显式拒绝。
- 40项库测试；README示例纳入实际ZIP和注册表独立消费验证。工具从moon.mod读取版本。

## 0.1.0 — 2026-10-21

- 发布纯MoonBit libconfig格式解析、查询、group编辑和规范化写出。
- 提供资源限制、字节字符串、31项测试、三后端构建及双平台CI。
- 固定上游1.8.2真实差分与双向读写、ZIP消费及Mooncakes消费验证。
