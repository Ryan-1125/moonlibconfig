# moonlibconfig

纯 MoonBit 的 libconfig 配置库，独立实现，参照 hyperrealm/libconfig 1.8.2，原创代码采用 Apache-2.0。[GitHub仓库](https://github.com/Ryan-1125/moonlibconfig)公开可用；尚未发布到 Mooncakes。

支持内存解析、类型保真、路径查询、替换和规范化写出。核心没有文件I/O或FFI依赖；group、同类型标量array、异构list、32/64位整数独立建模。字符串保存字节，提取String时严格检查UTF-8。

安装MoonBit工具链后，可从源码运行：

```text
git clone https://github.com/Ryan-1125/moonlibconfig.git
cd moonlibconfig
moon update
moon run examples/service --target wasm-gc
```

示例会读取服务名、端口和节点地址，将端口从9000替换为8080，写出并重读验证；出错以非零状态退出。[三个使用场景](docs/USE_CASES.md)说明接入方式和边界。

```moonbit
///|
test "service configuration" {
  let config = @config.parse("server={port=9000} peers=({host=\"moon\"})")
  assert_eq(config.lookup("peers[0].host").as_string(), "moon")
  let changed = config.replaced(@config.parse_path("server.port"), @config.Integer(8080))
  let text = @config.stringify(changed)
  assert_eq(@config.parse(text).lookup("server.port").as_int(), 8080)
}
```

消费包在moon.pkg导入 `"Ryan-1125/moonlibconfig" @config`。当前通过moon.work使用本地模块，或运行tools/Test-Consumer.ps1验证实际发布ZIP的独立消费；尚无注册表安装证据。

接口包括parse、parse_bytes、stringify、parse_path；Value提供lookup/get_path/get_member/at/replaced、with_member/without_member，以及as_int/as_int64/as_double/as_bool/as_bytes/as_string。整数提取不隐式转换，ConfigError携带错误码、位置及消息。

修改嵌套group时，可先用with_member新增/替换字段或without_member删除已有字段，再用replaced放回原路径。新字段追加至末尾，替换保留原顺序，删除不存在的字段报missing_member。操作复制修改的容器，未修改分支共享；写出时仍检查手工构造的非法树。

默认输入/输出1 MiB、嵌套64层、节点100000、单字符串256 KiB，可用Limits调整。include、未知转义、NUL及非有限浮点明确拒绝；输出不保留注释和排版。[兼容性说明](docs/COMPATIBILITY.md)列出与Windows上游的8项实测差异，不宣称完全兼容。

库31组测试通过；Wasm GC、JS、Windows native均已运行。140个真实上游差分输入中，110个共同范围双向读写通过。[验证记录](docs/VERIFICATION.md)包含证据和复现方式，最新CI状态见[GitHub Actions](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)。

```text
moon fmt --check
moon check --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target native --deny-warn
moon info
moon package --list
```

上游版权及参考说明见NOTICE；前期查重和选型见docs/EVALUATION.md。本项目独立于MoonFCGI。
