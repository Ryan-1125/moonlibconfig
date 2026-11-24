# Changelog

## 0.3.0 — 2026-11-24

- 新增parse_target/parse_target_text，匹配libconfig 1.8.2数值、转义、NUL和注释读取语义，保留旧严格接口。
- 新增parse_with_includes：应用内容回调、规范ID循环检测、加载/展开预算、递归及原文件来源。
- 原文定点编辑采用目标策略并复查替换值，新增数字、字符串、数组、嵌套、浮点与多文件原应用回读案例。
- 严格默认值、确定性模糊回归及维护工具已集成。目标差分140输入读取零差异，116项双向读写，非有限值单列。
- Linux真实参照构建和回读加入CI；README及申报验收契约同步更新。

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
