# moonlibconfig

[![CI](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml/badge.svg)](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)
[![Mooncakes](https://img.shields.io/badge/Mooncakes-0.1.0-orange)](https://mooncakes.io/docs/Ryan-1125/moonlibconfig@0.1.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)

**MoonBit 原生 libconfig 格式配置库**，提供解析、类型化查询、配置编辑和规范化写出能力。

适合读取已有 C/C++ 应用的 libconfig 配置、生成部署参数，以及在 Wasm、JavaScript 和 native 后端复用配置处理逻辑。核心由纯 MoonBit 实现，不依赖 C/C++ FFI，文件读取和保存由调用方负责。

[Mooncakes 包](https://mooncakes.io/docs/Ryan-1125/moonlibconfig@0.1.0) · [GitHub 仓库](https://github.com/Ryan-1125/moonlibconfig) · [使用场景](docs/USE_CASES.md) · [兼容性说明](docs/COMPATIBILITY.md)

## 特性

- **保留配置类型**：区分32位整数、64位整数、浮点数、布尔值、字符串，以及 group、同类型标量 array 和异构 list。
- **读取 libconfig 文本**：支持嵌套配置、三类注释、字符串转义与拼接、尾逗号、多进制整数和64位整数标记。
- **查询和编辑**：支持命名成员、列表/数组索引、路径查询、严格类型提取，以及字段新增、替换和删除。
- **保存字符串字节**：保留非 UTF-8 内容；需要 MoonBit String 时显式执行严格 UTF-8 解码。
- **确定性写出**：生成可重读的规范化 ASCII 文本，保留值及类型，正确处理转义和浮点负零。
- **明确的错误和限制**：提供错误码、消息、字节位置，以及输入、输出、嵌套、节点和字符串大小限制。

## 安装

在使用这个库的 MoonBit 工程中执行：

```sh
moon add Ryan-1125/moonlibconfig@0.1.0
```

下方示例保存为 `config_test.mbt`，在对应包的 `moon.pkg` 中加入测试导入：

```text
import {
  "Ryan-1125/moonlibconfig" @config,
} for "test"
```

业务源码使用同一包时，去掉导入声明后的 `for "test"`。

## 快速开始

解析配置、查询节点、修改端口、新增字段，再写出并重读：

```moonbit
///|
test "read edit and write service configuration" {
  let source = @config.parse(
    "service={port=9000;enabled=true;} peers=({host=\"localhost\";weight=1L;})",
  )
  assert_eq(source.lookup("service.port").as_int(), 9000)
  assert_eq(source.lookup("peers[0].host").as_string(), "localhost")
  assert_eq(source.lookup("peers.[0].weight").as_int64(), 1L)

  let service = source.lookup("service").with_member("workers", @config.Integer(4))
  let changed = source
    .replaced(@config.parse_path("service"), service)
    .replaced(@config.parse_path("service.port"), @config.Integer(8080))

  let output = @config.stringify(changed)
  let reloaded = @config.parse(output)
  assert_eq(reloaded.lookup("service.port").as_int(), 8080)
  assert_eq(reloaded.lookup("service.workers").as_int(), 4)
  assert_eq(source.lookup("service.port").as_int(), 9000)

  let removed = service.without_member("workers")
  assert_eq(removed, source.lookup("service"))
}
```

运行示例测试：

```sh
moon test
```

编辑操作复制修改路径上的容器，保留原有成员顺序，新字段追加到末尾；未修改的分支共享。删除不存在的字段会报 `missing_member`。

## 类型与 API

| 能力 | 接口 |
| --- | --- |
| 文本/字节解析 | `parse`、`parse_bytes` |
| 规范化写出 | `stringify` |
| 路径解析与查询 | `parse_path`、`lookup`、`get_path` |
| 成员与索引查询 | `get_member`、`at` |
| 配置编辑 | `replaced`、`with_member`、`without_member` |
| 类型提取 | `as_int`、`as_int64`、`as_double`、`as_bool`、`as_string`、`as_bytes` |
| 类型名称 | `kind` |

整数提取采用严格类型规则：`as_int64` 不会隐式接收32位整数。`ScalarArray` 只接受同一类型的标量；`List` 可包含不同类型的值及嵌套容器。

`Text(Bytes)` 保存字符串字节，`as_string` 进行严格 UTF-8 解码；无效 UTF-8 返回 `invalid_utf8`。`as_bytes` 可直接提取原始字节。完整签名见 [公开 API](pkg.generated.mbti)。

## 错误与资源限制

错误通过 `ConfigError(Diagnostic)` 返回。`Diagnostic` 包含 `code`、`message`、`offset`、`line`、`column`；解析位置以字节计，行列从1开始，offset从0开始。查询和写出错误采用默认位置。

```moonbit
///|
test "handle a missing setting" {
  let root = @config.parse("port=9000")
  let code = try {
    ignore(root.lookup("missing"))
    "accepted"
  } catch {
    @config.ConfigError(d) => d.code
  }
  assert_eq(code, "missing_member")
}
```

| 限制 | 默认值 |
| --- | --- |
| 输入/规范化输出 | 1 MiB |
| 容器嵌套 | 64层，根 group 不计入 |
| 值节点 | 100000个，根 group 不计入 |
| 解码后单字符串 | 256 KiB |
| 查询/替换路径 | 256段 |

通过 `Limits` 调整解析和写出上限，容器嵌套最多设置为256层。例如：

```moonbit
///|
test "apply explicit resource limits" {
  let limits = { ..@config.Limits::default(), max_input: 4096, max_depth: 16 }
  let root = @config.parse("port=9000", limits~)
  assert_eq(root.lookup("port").as_int(), 9000)
  assert_eq(@config.parse(@config.stringify(root, limits~)), root)
}
```

## 兼容范围

格式参照固定为 **hyperrealm/libconfig v1.8.2**。项目提供明确范围内的独立实现：

- `@include` 返回 `unsupported_include`，不触发文件读取或路径展开。
- 未知或不完整转义、NUL 字节和非有限浮点明确拒绝。
- 写出使用十进制数值和规范化排版，不保留原始注释、空白及进制。
- 两项非十进制整数行为与实测 Windows 上游存在差异；交换大整数时优先使用十进制及显式 `L` 后缀。

完整行为、8项实测差异及双方结果见 [兼容性说明](docs/COMPATIBILITY.md)。资源限制同样适用于调用方手工构造的配置树。

## 示例与验证

从源码直接运行端到端服务配置示例：

```sh
git clone https://github.com/Ryan-1125/moonlibconfig.git
cd moonlibconfig
moon update
moon run examples/service --target wasm-gc
```

该示例读取服务参数、修改端口、规范化写出并重读，异常时返回非零状态。

| 验证项 | 结果 |
| --- | --- |
| 核心与边界测试 | 31项，覆盖三后端 |
| GitHub Actions | Ubuntu、Windows：检查、三后端构建/测试、示例、API及打包 |
| 真实上游差分 | 140个输入，8项精确记录的差异 |
| 共同范围双向读写 | 110个输入通过 |
| 实际 ZIP 独立消费 | Wasm GC、JS、Windows native 通过 |
| Mooncakes 0.1.0 独立消费 | 注册表下载安装及三后端 API 调用通过 |

真实上游参照使用固定提交构建的外部程序；测试比较接受/拒绝、值结构、类型与数据。详见 [验证记录](docs/VERIFICATION.md)及 [CI](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)。

本地检查：

```sh
moon fmt --check
moon check --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon info
moon package --list
```

## 许可证与参考

本项目原创代码使用 [Apache-2.0](LICENSE)。

格式参考 [hyperrealm/libconfig v1.8.2](https://github.com/hyperrealm/libconfig/tree/v1.8.2)，上游源码许可证为 **LGPL-2.1-or-later**。MoonBit 实现依据公开格式文档独立编写；没有复制或翻译上游解析器及测试源码。上游程序仅作为外部行为参照使用，来源和参考范围见 [NOTICE](NOTICE)。
