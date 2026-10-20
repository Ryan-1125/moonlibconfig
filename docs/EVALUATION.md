# libconfig 方向评估

核实日期：2026-10-20（Asia/Shanghai）。状态：前期评估完成，尚未实现解析器、验证互操作或发布。

## 结论

建议继续开展一个面向 **hyperrealm/libconfig 文件格式**的纯 MoonBit 库，暂名 moonlibconfig。目标是让 MoonBit 程序消费已有 C/C++ 应用的配置，并生成可供这些应用读取的配置。价值在于既有格式互操作及类型保真；一般的新项目配置需求已有 TOML、INI、JSON 等选择，不能仅以“配置库”作为差异化理由。

本次 Mooncakes 检索未发现直接对应 hyperrealm/libconfig 的库。这是有限检索结论，不能证明整个生态不存在同类项目，也不代表赛事资格或审核结论。无需修改或依赖 MoonFCGI。

## 环境与继承边界

- 已完整读取根目录《MoonBit-跨项目交接.md》，保留原文件。
- 当前工作目录为 `D:\GitHub\moonlibconfig`，初始只有交接文档，没有 `.git`；没有发现适用的现有 AGENTS.md。
- 实测系统工具链：moon 0.1.20261020 (2284bd2)，moonc v0.10.16+b1a0e846e，moonrun 0.1.20261020。无需复用其他项目 SDK。
- 没有访问 MoonFCGI 工作树，没有复制其代码、Git 历史、SDK 或凭据，也没有调整全局工具链或编辑器配置。
- 本阶段未建远程仓库、推送、发布或报名。

## Mooncakes 查重

实际通过 `moon search <keyword> --limit 100 --json` 查询注册表，并保存原始 JSON 至 [evidence](evidence/)。搜索词为 libconfig、config、configuration、ini、toml；补充查询 hyperrealm、lib config。

- `libconfig`：3 个结果，为 hnlyxiaobing/MBOpenClacky、bobzhang/bap、dtzrttp/moonbit-rtl。命中来自应用内部 lib/config、ldconfig 或 lint 配置摘要，未见 libconfig 格式解析接口。
- `hyperrealm`：0 个结果。
- `lib config`：41 个结果，未发现直接对应库。
- config、configuration、ini 返回达到 100 的上限，因此不是全量枚举；toml 返回 55 个结果。搜索包含模块和包摘要，存在模糊命中，不能只看命中数量。

| 已核实存在的包 | 查询时版本 | 与本方向的关系 |
| --- | --- | --- |
| moonbit-community/toml | 0.5.0 | TOML 解析，通用配置替代选择；语法并非 libconfig |
| moonbit-community/ini | 0.2.3 | INI 解析；没有 libconfig 的同构数组/异构列表类型区分 |
| crh12354/moonconfigkit | 0.1.1 | INI/properties 合并、校验、审计，功能层有重合但输入格式不同 |
| mizchi/bit_config | 0.48.0 | Git config 解析，格式和键语义不同 |
| uiwcvb/hocon | 0.25.0 | HOCON 解析及迁移比较；有结构化配置重合，不能视作 libconfig 兼容实现 |
| Noverberrain/configscope | 0.5.0 | JSON 配置契约和兼容性检查，适合应用层而非本项目格式层 |
| xmyd0915/moonpkgconfig | 0.3.1 | pkg-config `.pc` 元数据；名字近似但格式、用途不同 |

版本和描述来自注册表当日响应，不据此认定维护质量、性能或兼容性。正式发布前重新查重并阅读可能新增的直接竞争项目。

## 上游基线与许可证

此处 libconfig 明确指 [hyperrealm/libconfig](https://github.com/hyperrealm/libconfig)，不是 pkg-config、Kconfig、HOCON 或其他同名项目。

- [官网](https://hyperrealm.github.io/libconfig/) 当前下载版本为 1.8.2。
- [官方标签](https://github.com/hyperrealm/libconfig/tags) 最新为 `v1.8.2`，日期 2025-12-14；当日 GitHub API 核实提交为 `a42cb47c1526a4f2ed025fcbb2289863375bc898`，见 `evidence/upstream-tags.json`。
- [官方手册](https://hyperrealm.github.io/libconfig/libconfig_manual.html) 标识 1.8.2，作为行为设计参考；网站内容可变化，实现和差分测试应固定上述 tag。
- 已读取并保存 [v1.8.2/LICENSE](https://raw.githubusercontent.com/hyperrealm/libconfig/v1.8.2/LICENSE) 原文；文件是 LGPL 2.1 文本。
- 已核实 [v1.8.2/lib/libconfig.c](https://raw.githubusercontent.com/hyperrealm/libconfig/v1.8.2/lib/libconfig.c) 开头授权为 LGPL 2.1 或后续版本，即 `LGPL-2.1-or-later`，不能把仓库页面的自动识别标签直接当作完整授权结论。原声明摘录保存在 evidence 中。

实现路线选择：依照公开格式文档独立编写 MoonBit 代码，使用自己编写的固定测试数据，不翻译或复制上游解析器、生成器、测试文件或手册正文；上游程序仅作为测试时外部行为参照。项目原创代码拟采用 Apache-2.0，在实际建立代码模块时加入完整许可证与参考说明。当前没有代码，尚未设置模块许可证元数据。

如后续改为移植、复制代码或引入上游测试，应逐文件核实授权，保留版权和授权声明，重新处理衍生部分许可证及分发要求；不能将这些部分直接标成 Apache-2.0。独立实现的计划本身不是对任意后续代码的法律结论。上游文档和源码也不因“参考”而失去其原有权利。

## 首版范围：0.1.0 目标

以下是待实现和验收的目标，不是支持声明。

| 层面 | 纳入首版 | 明确边界 |
| --- | --- | --- |
| 输入 | 内存文本解析，根为有序 group | 无隐式磁盘读取；输入大小先检查 |
| 结构 | group、同类型标量 array、异构 list | 三者独立建模，不统一转成 Json |
| 标量 | 32 位整数、64 位整数、Double、Bool、字符串 | 保留 Int32/Int64 区分，拒绝越界与非有限浮点 |
| 语法 | `=` / `:`、可选分号、三类注释、尾逗号、相邻字符串拼接 | 标识符按上游 ASCII 规则；不扩展环境变量或表达式 |
| 数值 | 十进制、二/八/十六进制、L 后缀、浮点指数 | 固定 1.8.2；非十进制按位宽的类型判定须专项验证 |
| 字符串 | 上游转义及原始 UTF-8 内容 | `\xHH` 是字节，不能误做 Unicode 码点；内部字节表示先于 String 便利接口 |
| 查询 | 命名成员、列表/数组索引、显式类型提取 | 区分不存在、类型不符、越界；无默认数值自动转换 |
| 写出 | 确定性规范化文本，保持值和类型 | 不保留注释、原始空白、数值进制或 include 指令 |
| include | 遇到 `@include` 返回明确不支持错误 | 首版不做路径解析、递归展开、glob 或文件回调 |
| 错误/限制 | 错误码、位置、消息；输入/嵌套/节点/字符串上限 | 失败不得返回伪成功的部分配置；重复键报错 |

应先确定输入接口的字节语义：libconfig 是字节导向，`\xFF` 可能产生非 UTF-8 字节。如果仅使用 MoonBit String，无法准确覆盖该情况。建议底层 `parse_bytes(Bytes)`、字符串值为 Bytes；`parse(String)` 是 UTF-8 编码便利接口，字符串提取时显式返回 UTF-8 解码结果或错误。不要在实现后悄悄丢弃此差异。

资源上限建议默认输入 1 MiB、容器嵌套 64 层、节点 100000、解码后单字符串 256 KiB。配置参数应有明确有效范围，边界采用字节计数；这些是本库限制，不宣称来自上游。

暂缓：C/C++ FFI、文件 API、include 展开、schema、配置合并、热重载、注释保真编辑、CLI、性能领先宣传。首版集中形成可独立依赖的格式库。

## 实施顺序与验收

1. 建立独立模块、原创许可证、发布排除规则；先完成有序配置树、类型和错误模型及资源限制定义。
2. 实现字节词法分析和递归下降解析；用手写固定向量覆盖所有值类型、注释、字符串和数值边界。
3. 增加查询及规范化写出；不仅做自往返，还检查固定预期值、Int32/Int64 保真、数组同类型约束和输出转义。
4. 增加畸形输入和资源上限测试：重复键、未闭合字符串/注释、非法转义、溢出、容器不匹配、混合数组、深度和长度的恰好边界及超限。
5. 固定构建上游 v1.8.2 的外部测试程序，对共同支持范围比较接受/拒绝、树结构及类型；本库写出由上游读取、上游写出由本库读取。include 和本库资源限制单独列为有意差异。
6. 运行格式检查、check、测试、API 生成；目标 wasm-gc、JS、native。当前只核实 Windows 工具链，其他平台通过后才能宣称支持。
7. 在当前模块之外建立临时消费者工程做本地包消费验证；之后再安排干净 CI。正式发布前 `moon package --list` 检查，不将证据、交接文件、临时消费者、凭据或本地 SDK 打入库包。

验收重点：实际读取一个手写服务配置，正确提取嵌套字段及列表元素；修改值并规范化写出；由真实上游程序确认类型和值。差分测试程序未运行之前只能称“以 1.8.2 为目标”，不能称“兼容已验证”。

## 当前完成与未完成

已完成交接读取、目录/工具链核实、注册表查重、上游 tag/许可证核实和首版范围设计。网络首次受限，后续获准的只读访问成功，证据来自成功请求。

尚未开始产品代码、编译测试、上游差分验证、CI、独立消费或发布。本轮交付是实施前评估，不将文档检查计为实现测试通过。
