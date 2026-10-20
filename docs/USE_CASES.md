# 使用场景与验收入口

以下是技术事实清单，供参赛者理解和人工撰写申报书；不是代写的申报书，也不声称已有真实用户部署。

## 1. 读取已有C/C++服务配置

服务管理工具接收已有libconfig文本，通过parse读取嵌套服务字段、同构数组和异构节点列表，严格提取端口、开关、64位计数和地址。配置中出现include时明确拒绝，由调用方预处理；不会悄悄读磁盘。运行moon run examples/service可查看端到端最小示例。

## 2. 生成或更新配置

部署工具读取配置树，用replaced替换现有字段，stringify生成确定性文本，再交给外部程序保存。Int64显式带L，字节字符串正确转义。修改路径之外的分支共享，写出会丢弃原注释和排版；不适合要求保真编辑的用途。Test-Consumer.ps1覆盖独立包中查询、修改、写出和重读流程。

## 3. 跨后端配置检查

相同配置检查逻辑可在MoonBit Wasm、JS及native后端复用，通过Limits约束输入、嵌套、节点和字符串大小；错误提供代码及字节位置。浏览器/命令行宿主自行负责输入输出。用moon test --target wasm-gc、js、native复现核心检查；Windows真实上游比对见tools/differential.mjs。

通用配置需求已有TOML、INI等成熟选择。本库的具体价值是libconfig既有格式与MoonBit之间的值/类型互操作，不宣称对所有新项目配置更优。兼容范围以COMPATIBILITY.md为准。
