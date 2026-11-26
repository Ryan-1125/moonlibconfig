# moonlibconfig

[![CI](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml/badge.svg)](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-0.3.0-orange)](https://mooncakes.io/docs/Ryan-1125/moonlibconfig@0.3.0)

**纯 MoonBit 的 libconfig 配置处理库**：读取、严格查询、配置编辑、校验、源位置、回调式多文件包含及原文定点修改。

固定参照 **hyperrealm/libconfig v1.8.2**。完整格式兼容是演进目标，验收按读取结果、写出能力、原应用回读三层分别记录；固定语料通过不等于任意输入已完全兼容。

## 安装与使用

在消费工程执行：

```sh
moon add Ryan-1125/moonlibconfig@0.3.0
```

下面代码保存为 `config_test.mbt`，在对应的 `moon.pkg` 中导入：

```text
import { "Ryan-1125/moonlibconfig" @config } for "test"
```

业务源码调用时去掉 `for "test"`。运行 `moon test` 可执行示例。

### 目标应用一致的数值解释

`parse_target(Bytes)` 返回带位置的 Document，采用 libconfig 1.8.2 目标解释。部分非十进制整数先作32位符号转换再应用L后缀，超出有符号64位的值报错。

```moonbit
///|
test "target interpretation and normalized readback" {
  let doc = @config.parse_target(b"mask=0xFFFFFFFFL; bits=0x100000000L; port=9000;")
  assert_eq(doc.get_int64("mask"), -1L)
  assert_eq(doc.get_int64("bits"), 4294967296L)
  let root = doc.root().replaced(@config.parse_path("port"), @config.Integer(8080))
  assert_eq(@config.parse_target_text(@config.stringify(root)).root(), root)
}
```

现有 `parse`、`parse_bytes`、`parse_document` 保留原先的严格、可移植规则，兼顾已有使用者。与原 libconfig 应用交换配置时显式使用 `parse_target` 或 `parse_with_includes`；不要混用两套数值解释。两种入口的规则及历史差异见[兼容性说明](docs/COMPATIBILITY.md)。

### 编辑既有配置，保留无关字段语义

`replace_source_value` 用目标策略读取，仅替换指定值的原始区间，其余字节原样保留；写出前再次检查目标解释下的值和类型是否等于请求的替换值。字符串拼接与注释、数值进制等无关内容保留。

```moonbit
///|
test "edit original text without reinterpreting unrelated values" {
  let original = b"mask=0xFFFFFFFFL; port=9000; title=\"moon\";"
  let edited = @config.replace_source_value(original, "port", @config.Integer(8080))
  assert_eq(edited, b"mask=0xFFFFFFFFL; port=8080; title=\"moon\";")
  assert_eq(@config.parse_target(edited).get_int64("mask"), -1L)
  let changed_mask = @config.replace_source_value(edited, "mask", @config.Integer64(4294967295L))
  assert_eq(@config.parse_target(changed_mask).get_int64("mask"), 4294967295L)
}
```

树级 `stringify` 输出确定性ASCII、十进制整数、显式L和字节转义，保留值树而不保留排版。应用要求保留原文时使用定点编辑接口。

### 多文件配置：应用提供内容，库负责展开与定位

`parse_with_includes` 在指令出现的位置展开文本，支持根级、group及list中的包含。指令单独占行，路径为单行双引号字面量。库接收 `resolve(parent_id, requested_path) -> IncludeFile` 回调，不访问文件系统。

回调负责路径/访问策略并返回稳定的规范ID；库负责递归、规范ID循环检测、累计加载字节/展开字节限制、重复键解析和原文件定位。默认包含深度10，最大32，根深度为0。同一ID对应不同内容会报错。每次加载均计入累计预算。

```moonbit
///|
test "resolve files and locate original child values" {
  let root : @config.IncludeFile = {
    id: "root.cfg",
    content: b"service={\n@include \"child.cfg\"\n}\n",
  }
  let doc = @config.parse_with_includes(root, (parent, requested) => {
    if parent != "root.cfg" || requested != "child.cfg" {
      raise @config.resolver_error("unknown source")
    }
    { id: "child.cfg", content: b"port=9000; mask=0xFFFFFFFFL;" }
  })
  assert_eq(doc.root().lookup("service.port").as_int(), 9000)
  assert_eq(doc.root().lookup("service.mask").as_int64(), -1L)
  guard doc.origin("service.port") is Some(origin) else { fail("missing origin") }
  assert_eq(origin.source, "child.cfg")
  assert_eq((origin.position.line, origin.position.column), (1, 6))
}
```

`origin` 返回原文件ID及字节位置；跨文件错误携带来源ID。EOF缺值错误定位最近的有效输入字节。修改子文件时，用其原内容调用 `replace_source_value`，保存到对应文件，保留根文件及包含关系。通配符、目录权限和虚拟文件系统属于回调的应用策略；库不隐式猜测路径。

### 配置树、校验和严格默认值

group、同类型标量array和异构list分别建模；Int32/Int64不隐式转换。编辑接口复制修改的容器，未改变分支共享。

```moonbit
///|
test "edit containers validate and read defaults" {
  let root = @config.parse("service={port=9000} peers=(\"one\",\"two\")")
  let peers = root.lookup("peers").inserted(1, @config.Text(b"backup")).removed_at(0)
  let updated = root.replaced(@config.parse_path("peers"), peers)
  assert_eq(@config.validate(updated), [])
  assert_eq(updated.lookup_or("workers", @config.Integer(4)), @config.Integer(4))
  assert_eq(updated.lookup_optional("absent"), None)
  assert_eq(@config.parse(@config.stringify(updated)), updated)
}
```

`lookup_optional` 只把不存在的成员/索引作为None；`lookup_or` 仅对缺失使用默认值。已有值类型不符、非法路径、沿标量继续查询仍报错，不用默认值掩盖配置错误。

`validate` 独立检查根、名称、重复键、array类型、NUL、有限浮点及节点/深度/字符串预算，返回带路径的多项问题。达到全局节点预算时终止，超深分支单独截断。校验不分配序列化文本，max_input的文本预算由解析/写出入口执行。

## 类型、错误及预算

| 能力 | 接口 |
| --- | --- |
| 目标应用解析 | `parse_target`、`parse_with_includes` |
| 严格可移植解析 | `parse`、`parse_bytes`、`parse_document`、`parse_document_bytes` |
| 读取与默认值 | `lookup`、`get_path`、`get_member`、`at`、`lookup_optional`、`lookup_or` |
| 树编辑 | `replaced`、`with_member`、`without_member`、`inserted`、`appended`、`removed_at` |
| 输出及校验 | `stringify`、`replace_source_value`、`validate` |
| 类型读取 | `as_int`、`as_int64`、`as_double`、`as_bool`、`as_bytes`、`as_string` |
| 定位 | `Document.location`、`Document.get_*`、`IncludedDocument.origin` |

错误通过 `ConfigError(Diagnostic)` 返回，含code、message、offset、line、column。行/字节列从1开始，offset从0开始。Document及include位置是原输入快照，不随共享容器的后续修改更新。

默认输入/输出1 MiB、容器64层、节点100000、解码后字符串256 KiB，查询路径256段。`Limits`可调整预算，容器深度上限256。Include累计输入与展开输出分别执行max_input预算，容器/节点预算在最终配置树上执行。

目标模式按原应用读取NUL之前的C字符串内容，保留未知转义原文，并匹配EOF块注释行为。浮点溢出可读为无穷大；规范化写出明确报错，不能把不可写值计作成功往返。原文编辑可保留无关的这类字段。

## 验收与复现

仓库源码使用moonc 0.10.22及对应标准库，并适配新版格式器的#derive语法。本机旧SDK保持原样，可通过tools/Use-ProjectToolchain.ps1在进程级使用项目.local中的隔离工具链，例如 `./tools/Use-ProjectToolchain.ps1 test --target native --deny-warn`。CI使用官方当前工具链。Mooncakes 0.3.0包已在0.10.16和0.10.22工具链中分别完成消费验证。

| 层次 | 测试契约 |
| --- | --- |
| 目标模式读取 | 固定140个输入，要求接受/拒绝和类型/值与真实v1.8.2一致 |
| 目标模式写出 | 116个输入双向读写；单独记录1个非有限浮点不可规范化写出的用例 |
| 旧模式回归 | 原140个输入及8项明确规则保留，保护既有行为 |
| 原应用编辑回读 | 8个场景，仅指定字段变化，其他值与类型逐字段相等 |
| 多文件工作流 | 递归展开、子文件编辑、原应用重读、来源、循环、总量及失败测试 |
| 工程化 | 三后端测试、ZIP/注册表独立消费、种子模糊回归及双平台CI |

测试覆盖不构成对任意配置完全兼容的证明。[完整兼容目标及验收矩阵](docs/ACCEPTANCE.md)记录验证范围、平台、规则与来源；[验证记录](docs/VERIFICATION.md)保存执行结果；[CHANGELOG](CHANGELOG.md)记录版本变化。

```sh
git clone https://github.com/Ryan-1125/moonlibconfig.git
cd moonlibconfig
moon update
moon fmt --check
moon check --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon run examples/service --target wasm-gc
```

Windows参照构建：运行 `tools/Get-Upstream.ps1`、`tools/Build-Oracle.ps1`。Linux参照构建：`bash tools/Build-Oracle-Unix.sh`。随后执行：

```sh
node tools/differential.mjs
node tools/differential.mjs --target-profile
node tools/semantic-edit.mjs
```

## 开源与参考

原创MoonBit代码采用 [Apache-2.0](LICENSE)。参照项目 [hyperrealm/libconfig v1.8.2](https://github.com/hyperrealm/libconfig/tree/v1.8.2) 的源码采用 LGPL-2.1-or-later。实现独立编写，格式及已验证的上游行为为设计依据，不复制或翻译上游实现与测试源码。参考范围及原始授权见 [NOTICE](NOTICE)。

## 最终验收复现

运行 ./tools/Verify-Acceptance.ps1 可依次完成源码检查、三后端构建测试、API快照、ZIP及注册表独立消费、真实上游差分和原应用回读。脚本生成带源码提交、版本及逐步骤结果的 .local/acceptance/report.json。环境与材料对应关系见 [最终验收入口](docs/FINAL_ACCEPTANCE.md)。
