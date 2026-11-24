# 兼容目标与重新申报验收矩阵

## 最终目标

覆盖libconfig 1.8.2格式、默认文本包含及目标应用数据解释。库继续由MoonBit承担解析、编辑、校验、展开与定位；应用仅提供内容和保存策略。阶段性共同范围不作为最终兼容终点。

## 当前0.3.0验收

| 编号 | 用例与操作 | 成功条件 |
| --- | --- | --- |
| N1 | 0xFFFFFFFFL、0xffffffffffffffff、前导零及32/64位边界 | 目标模式与上游类型、值及接受/拒绝一致 |
| S1 | 原八项差分的完整语料 | 目标模式140输入读取零差异，旧模式保留独立规则 |
| W1 | 双方规范化输出再交给对方 | 116输入值和类型保持一致；非有限浮点单列 |
| E1 | 修改port | 原应用重读仅port变化，包括mask的大整数值不变 |
| E2 | 修改mask本身为4294967295L | 原应用观察到请求的Int64值，其他值/类型不变 |
| E3 | 修改字符串、字节串、数组、嵌套布尔、浮点 | 分别逐字段比较预期树；负零等非目标值保持 |
| I1 | 根级、group、list、嵌套include | 回调参数、展开树及原文件位置正确 |
| I2 | alias规范身份循环、深度、累计字节、重复键、缺文件 | 明确失败，不能返回部分成功配置 |
| I3 | 修改child.cfg中的service.bits，根包含关系保留 | 同一上游应用从原根重读，仅service.bits改变 |

N1/I1/I2等由compatibility_wbtest.mbt验证。E1-E3/I3由真实libconfig消费者执行，共8个原应用回读场景；不是用本库自往返冒充互操作。

## 八项差分的处置

两项数字差异已在parse_target中匹配上游，原文编辑也采用目标策略。其余六项读取规则同样按目标行为处理。旧parse接口保留0.2.0规则，兼顾现有用户，不将旧模式八项差异写成新目标模式仍存在的差异。

1e999可被目标和上游读为无穷大，但不是规范化写出成功的输入。已明确记录读取与写出的不同结果；原文修改另行验证未修改非有限值保留。不能把这项用例算入116项双向成功。

## 原应用案例

原始文件包含mask=0xFFFFFFFFL、bits=0x100000000L、port=9000、ratio=-0.0、字节字符串、普通字符串、数组和嵌套配置。原程序先读取并记录完整类型化树；MoonBit逐次修改一个目标值；同一原程序再读取。预期树只替换指定路径，所有其他节点包括类型均逐项相等。

多文件案例由原程序从含@include的根读取，MoonBit回调展开并验证来源；只写回被修改子文件，根文件及包含关系不变，再由原程序重读比较。

## 复现

1. moon test --target wasm-gc / js / native：固定语义、资源和模糊回归。
2. Windows运行tools/Get-Upstream.ps1、tools/Build-Oracle.ps1；Linux运行bash tools/Build-Oracle-Unix.sh。
3. node tools/differential.mjs：旧模式回归。
4. node tools/differential.mjs --target-profile：目标模式读取及双向写出。
5. node tools/semantic-edit.mjs：八场景真实原应用回读。
6. tools/Test-Consumer.ps1：实际ZIP消费；tools/Test-RegistryConsumer.ps1：发布版本消费。

CI在Ubuntu和Windows运行真实参照测试。证据按平台保存，已执行结果见VERIFICATION.md；固定语料不推断未执行环境，也不代表任意合法输入已经穷尽。
