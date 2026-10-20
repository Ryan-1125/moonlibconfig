# 验证记录

初次执行2026-10-20，补充验证2026-10-21（Asia/Shanghai）；Windows x64；moon 0.1.20261020 / moonc v0.10.16+b1a0e846e。

- 库单元测试27组，覆盖固定树、数值边界、字节字符串/拼接、注释、查询更新、畸形输入、写出、资源限制、NUL、截断输入，以及公共API路径上限和手工构造循环树的拒绝。
- Wasm GC、JS、Windows native均已运行。其他操作系统本地运行尚未验证。
- 真实上游v1.8.2提交a42cb47c1526a4f2ed025fcbb2289863375bc898使用MSVC构建。源码和二进制仅在被忽略的.local/upstream，不复制上游Git仓库。
- 140个原创固定/确定性生成输入比较接受/拒绝、树结构、类型和值；8项精确已知差异，0项未解释差异。110个共同接受且值一致的输入完成双向写出/读取。完整报告见evidence/differential-windows.json。
- 发布ZIP解压至系统临时目录，另建消费者模块，通过公开API查询、更新、写出、重读；三个目标各通过1项消费测试（workspace共28项含库27项）。不是注册表安装验证。
- 发布清单排除.local、工具、上游源码/二进制、交接文件、凭据及查重原始响应。repository元数据已指向公开GitHub仓库。
- [GitHub仓库](https://github.com/Ryan-1125/moonlibconfig)已创建并推送。CI覆盖Ubuntu/Windows的检查、三后端构建/测试、示例、API和打包；Windows额外执行独立ZIP消费及真实上游差分。各提交结果见[Actions](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)，不能用旧提交成功替代当前提交结果。尚未发布Mooncakes或通过赛事审核。

首次CI中Ubuntu通过，Windows格式检查遇到CRLF差异及差异输出路径错误，记录见[首次运行](https://github.com/Ryan-1125/moonlibconfig/actions/runs/39453902185)。随后提交.gitattributes统一文本为LF并重新验证，没有删除失败记录或跳过格式检查。

examples/service现有直接可运行的解析、查询、修改、写出、重读示例；Wasm GC/JS/native均执行通过，出错会返回非零状态。使用场景见USE_CASES.md，非代写申报书。

基本复现命令：moon version --all、moon update、moon fmt --check、moon check --deny-warn、moon test --target wasm-gc --deny-warn、moon test --target js --deny-warn、moon test --target native --deny-warn、moon info、moon package --list。

Windows独立ZIP消费：运行tools/Test-Consumer.ps1。Windows真实差分：依次运行tools/Get-Upstream.ps1、tools/Build-Oracle.ps1、node tools/differential.mjs。需要MSVC x64和Windows SDK；构建脚本支持路径参数。

下载脚本固定官方提交并校验SHA256；Node脚本退出时恢复桥的smoke输入。报告保存在.local/differential/report.json，审阅后才更新证据。上游编译的三个宏重复定义警告来自其Windows兼容头；本库检查不忽略一般警告。
