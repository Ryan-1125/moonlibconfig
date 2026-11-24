# 项目定位与技术选型

## 项目结论

moonlibconfig 是已发布的 MoonBit 原生 libconfig 格式配置库，当前版本为0.3.0。项目面向既有C/C++应用配置与MoonBit程序之间的读写互操作，保持32/64位整数、同类型标量数组和异构列表等类型区别。

项目已交付解析、查询、编辑、校验、规范化写出及源位置诊断，完成GitHub双平台CI、Mooncakes发布和独立安装验证。结果见[开发与交付记录](DEVELOPMENT.md)和[验证记录](VERIFICATION.md)。

## 生态定位

2026-10-20通过Mooncakes注册表检索libconfig、hyperrealm、config、configuration、ini、toml及lib config等关键词。该次检索未发现直接对应hyperrealm/libconfig的实现；config等宽泛关键词受100条结果上限约束，不能据此断言整个生态没有同类项目。

| 相关项目 | 与本项目的关系 |
| --- | --- |
| moonbit-community/toml | TOML格式解析，适合一般配置需求 |
| moonbit-community/ini | INI格式解析 |
| crh12354/moonconfigkit | INI/properties合并、校验及审计 |
| mizchi/bit_config | Git config格式解析 |
| uiwcvb/hocon | HOCON格式解析及迁移比较 |
| Noverberrain/configscope | JSON配置契约及兼容性检查 |
| xmyd0915/moonpkgconfig | pkg-config元数据，格式与用途不同 |

本项目的差异点为libconfig格式及其类型语义，不是通用配置合并或审计功能。原始查询响应、当日版本和检索摘要保存在[evidence](evidence/)中，作为选型证据。

## 固定参照与许可证

- 参照项目：[hyperrealm/libconfig](https://github.com/hyperrealm/libconfig)。
- 固定版本：v1.8.2，提交a42cb47c1526a4f2ed025fcbb2289863375bc898。
- 行为参考：[官方格式手册](https://hyperrealm.github.io/libconfig/libconfig_manual.html)及固定版本外部程序。
- 上游源码声明：LGPL-2.1-or-later，授权证据保存在evidence中。
- 本项目原创代码：Apache-2.0，完整文本见[LICENSE](../LICENSE)，参考范围见[NOTICE](../NOTICE)。

MoonBit代码依据公开格式文档独立实现，没有复制或翻译上游解析器及测试源码；上游程序仅用于外部差分验证。

## 已落实的技术方案

| 选择 | 实现及理由 |
| --- | --- |
| 纯MoonBit核心 | 不依赖文件I/O与FFI，支持Wasm GC、JS及native |
| 字节扫描与递归下降 | 处理嵌套语法，记录字节位置，执行资源预算 |
| 独立值模型 | group、array、list和各标量类型分别建模 |
| Bytes字符串 | 保留非UTF-8字节，需要String时严格解码 |
| 复制式编辑 | 保留源容器及成员顺序，未修改分支共享 |
| 独立校验 | 不通过序列化检查结构、重复键、类型和资源问题 |
| Document源位置 | 原输入位置快照，查询错误定位到原值或父节点 |
| 固定参照验证 | 用真实v1.8.2程序比较结构、类型和值及双向读写 |

默认资源上限为输入/输出1 MiB、嵌套64层、100000个值节点、单字符串256 KiB。具体语法、类型规则和8项实测差异见[兼容性说明](COMPATIBILITY.md)。

## 完成范围

0.2.0已实现内存解析、配置编辑、路径查询、严格类型提取、规范化写出、独立校验、源位置和结构化错误。文件读写由调用方负责；include、未知转义、NUL及非有限浮点采用显式拒绝策略。输出不保留原始注释、空白或数值进制。

这些是已发布版本的明确接口和行为范围；公开使用入口为[README](../README.md)和[使用场景](USE_CASES.md)。

## 0.3.0兼容性更新

parse_target采用上游1.8.2目标解释；parse_with_includes提供受控内容回调、递归、循环/预算及原文件来源。原文定点编辑与八场景真实原应用回读见ACCEPTANCE.md。旧parse接口的严格规则保留，不能把旧模式范围套用于新目标入口。
