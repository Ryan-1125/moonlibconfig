# 使用场景

moonlibconfig 0.3.0提供以下三类可复用工作流；对应API、运行示例及验证入口均已交付。

## 1. 读取已有C/C++服务配置

服务管理工具接收已有libconfig文本，通过parse读取嵌套服务字段、同构数组和异构节点列表，严格提取端口、开关、64位计数和地址。跨应用读取使用parse_target；多文件通过parse_with_includes回调提供内容，由库展开、检查循环及预算并映射原文件位置。运行moon run examples/service可查看端到端最小示例。

## 2. 生成或更新配置

部署工具读取配置树，用with_member/without_member新增或删除字段，用inserted/appended/removed_at编辑列表及数组，再用replaced放回嵌套路径；validate独立校验后由stringify生成确定性文本，交给外部程序保存。Int64显式带L，字节字符串正确转义。修改路径之外的分支共享，写出会丢弃原注释和排版；不适合要求保真编辑的用途。Test-Consumer.ps1覆盖独立包中查询、修改、写出和重读流程。

## 3. 跨后端配置检查

相同配置检查逻辑可在MoonBit Wasm、JS及native后端复用，通过Limits约束输入、嵌套、节点和字符串大小；Document保留字段与值的起始位置，严格类型查询指出字段路径、期望/实际类型；独立validate返回带路径的结构和资源问题。浏览器/命令行宿主自行负责输入输出。用moon test --target wasm-gc、js、native复现核心检查；Windows真实上游比对见tools/differential.mjs。

通用配置需求已有TOML、INI等成熟选择。本库的具体价值是libconfig既有格式与MoonBit之间的值/类型互操作，不宣称对所有新项目配置更优。兼容范围以COMPATIBILITY.md为准。

## 0.3.0兼容性更新

parse_target采用上游1.8.2目标解释；parse_with_includes提供受控内容回调、递归、循环/预算及原文件来源。原文定点编辑与八场景真实原应用回读见ACCEPTANCE.md。旧parse接口的严格规则保留，不能把旧模式范围套用于新目标入口。
