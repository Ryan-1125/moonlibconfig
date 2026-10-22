# 验证记录

## 0.2.0 — 2026-10-22

新增容器编辑、独立校验和源位置接口，库测试共40项。新增测试覆盖插入/删除顺序与源容器保留、数组类型与位宽拒绝、校验多问题与字段路径、循环树和预算截断、字段/值字节位置、带位置的严格类型查询、UTF-8错误和include拒绝。原0.1.0的行为测试保留。

实际ZIP消费者和注册表消费者均从README提取完整MoonBit示例，并读取moon.mod版本进行验证。40项库测试在wasm-gc、JS、Windows native通过；ZIP消费者每个目标通过45项（库40、README4、公开API消费1）。140个上游差分输入仍为110个共同范围双向读写通过、8项已知差异、0项新增差异。

0.2.0已于2026-10-22发布，publish返回200 OK，moon view确认服务端版本。包校验值c5bf2869c3cd9c9162a527bb7a9073c177cf3b6db79c15968691b751fcf82a31。全新无workspace/路径覆盖的工程从Mooncakes下载0.2.0，README四个示例在三后端全部通过。发布及消费证据见evidence/registry-release-0.2.0.json和evidence/readme-registry-0.2.0.json；历史0.1.0证据保留。

## 0.1.0 基线

初次执行2026-10-20，补充验证2026-10-21（Asia/Shanghai）；Windows x64；moon 0.1.20261020 / moonc v0.10.16+b1a0e846e。

- 库单元测试31组，覆盖固定树、数值边界、字节字符串/拼接、注释、查询更新、畸形输入、写出、资源限制、NUL、截断输入，以及公共API路径上限、手工构造循环树的拒绝、Unicode BOM保留和group增删改。
- Wasm GC、JS、Windows native均已在本机运行；GitHub Actions的Ubuntu、Windows均通过三后端构建和测试。
- 真实上游v1.8.2提交a42cb47c1526a4f2ed025fcbb2289863375bc898使用MSVC构建。源码和二进制仅在被忽略的.local/upstream，不复制上游Git仓库。
- 140个原创固定/确定性生成输入比较接受/拒绝、树结构、类型和值；8项精确已知差异，0项未解释差异。110个共同接受且值一致的输入完成双向写出/读取。完整报告见evidence/differential-windows.json。
- 发布ZIP解压至系统临时目录，另建消费者模块，通过公开API查询、更新、写出、重读；三个目标各通过1项消费测试（workspace共32项含库31项）。不是注册表安装验证。
- 发布清单排除.local、工具、上游源码/二进制、交接文件、凭据及查重原始响应。repository元数据已指向公开GitHub仓库。
- [GitHub仓库](https://github.com/Ryan-1125/moonlibconfig)公开可访问。CI覆盖Ubuntu/Windows的检查、三后端构建/测试、示例、API和打包；Windows额外执行独立ZIP消费及真实上游差分。[提交9198942的完整验证](https://github.com/Ryan-1125/moonlibconfig/actions/runs/39456277128)全部通过；各提交结果见[Actions](https://github.com/Ryan-1125/moonlibconfig/actions/workflows/ci.yml)。

## Mooncakes发布与注册表独立消费

Ryan-1125/moonlibconfig 0.1.0已于2026-10-21发布。注册表元数据显示该版本未撤回，包校验值为317d540b794f9c882a1c3069befb4059cc53d713fa99fbecd3eb8d2dbf927c2c。

用户终端的publish返回200 OK，随后通过moon view再次核实服务端版本。首次安装遇到索引更新失败，使用系统已有代理在当前进程刷新索引后，独立消费者成功下载安装；没有重复发布或修改全局工具链。

无workspace/本地路径覆盖的全新临时工程，使用Mooncakes的0.1.0版本依赖，验证了解析、查询、字段增删、路径替换、写出和重读；Wasm GC、JS、Windows native均通过。

README中的三个MoonBit示例可直接通过tools/Test-RegistryConsumer.ps1从Markdown提取，在全新临时工程中使用注册表版本执行。发布元数据和验证结果见evidence/registry-release-0.1.0.json及evidence/readme-registry-0.1.0.json。

首次CI中Ubuntu通过，Windows格式检查遇到CRLF差异及差异输出路径错误，记录见[首次运行](https://github.com/Ryan-1125/moonlibconfig/actions/runs/39453902185)。随后提交.gitattributes统一文本为LF并重新验证，没有删除失败记录或跳过格式检查。

examples/service现有直接可运行的解析、查询、修改、写出、重读示例；Wasm GC/JS/native均执行通过，出错会返回非零状态。使用场景见USE_CASES.md，非代写申报书。

基本复现命令：moon version --all、moon update、moon fmt --check、moon check --deny-warn、moon test --target wasm-gc --deny-warn、moon test --target js --deny-warn、moon test --target native --deny-warn、moon info、moon package --list。

Windows独立ZIP消费：运行tools/Test-Consumer.ps1。Windows真实差分：依次运行tools/Get-Upstream.ps1、tools/Build-Oracle.ps1、node tools/differential.mjs。需要MSVC x64和Windows SDK；构建脚本支持路径参数。

下载脚本固定官方提交并校验SHA256；Node脚本退出时恢复桥的smoke输入。报告保存在.local/differential/report.json，审阅后才更新证据。上游编译的三个宏重复定义警告来自其Windows兼容头；本库检查不忽略一般警告。
