# libconfig 1.8.2 兼容目标与验收契约

## 交付目标

moonlibconfig交付纯MoonBit的内存配置处理核心：解析、类型化查询、配置编辑、独立校验、源位置诊断和规范化写出。格式基线固定为hyperrealm/libconfig v1.8.2；参照程序固定提交a42cb47c1526a4f2ed025fcbb2289863375bc898，当前真实差分平台为Windows x64/MSVC。

兼容目标是**共同接受输入的值树与类型互操作**。比较范围包括Int32/Int64、浮点、布尔、字符串字节、group成员和array/list结构。文本排版、注释和原数值进制不作为相等条件。

## 多文件配置处理契约

当前公开发布版本0.2.0的parse、parse_bytes、parse_document接口接收完整的内存配置内容，不进行文件读取或include展开。含原始@include指令的输入返回unsupported_include，而不是跳过指令后继续产生不完整配置。

多文件应用通过宿主读取并按libconfig的文本包含语义展开，再将展开后的内容交给本库；文件路径、递归、循环与展开总量由宿主负责。这是接入方式，不是库内置include解析器的声明。库内Document位置对应实际传入文本，宿主展开后的来源映射也由宿主维护。

验收用例I1：直接解析包含@include的根配置或嵌套group，均明确返回unsupported_include，不调用磁盘接口，不返回部分成功的树。若申报的目标是“库内置多文件include”，则必须另行实现回调、来源映射、循环及预算测试后再将该能力列为交付项。

## 八项差分对往返的具体影响

| 用例 | 本库结果 | 对值与类型往返的影响 |
| --- | --- | --- |
| 未闭合块注释 | 拒绝 | 不产生值树，不计入成功往返集合 |
| 未知Unicode样式转义 | 拒绝 | 不产生值树，不以静默替换掩盖上游原字符串 |
| 十六进制转义含非法字符 | 拒绝 | 不产生值树 |
| 十六进制转义不足两位 | 拒绝 | 不产生值树 |
| 字符串NUL及后缀 | 拒绝 | 避免上游C字符串查询截断后与本库字节数据不同 |
| 0xFFFFFFFFL | 本库Int64(4294967295)，实测上游Int64(-1) | **跨实现值不同**，不属于共同值一致集合；本库内部往返保持4294967295L |
| 0xffffffffffffffff | 本库Int64(-1)，实测上游拒绝 | **接受范围不同**，不属于共同输入集合；本库内部写出-1L可保留值和类型 |
| 1e999 | 拒绝 | 不将无穷大当作可互操作的有限浮点值 |

因此，不能把“本库自身往返成功”写成“与上游对任意输入一致”。与参照程序交换上述大整数时，使用十进制4294967295L、-1L，显式固定64位类型。

## 可复现验收用例

| 编号 | 输入/操作 | 验收结果与入口 |
| --- | --- | --- |
| I1 | 根级或group中的@include | unsupported_include；submission_wbtest.mbt |
| V1 | 1与1L、同构array、异构list、嵌套group | 解析后值与类型符合固定预期；maturity_wbtest.mbt、parser_wbtest.mbt |
| V2 | 查询、增删改、stringify后重读 | 编辑后树相等，原树保留；editing_wbtest.mbt、maturity_wbtest.mbt |
| V3 | 非UTF-8字节、浮点负零 | 字节和数值符号保留；unicode_wbtest.mbt、writer_wbtest.mbt |
| D1 | 上表六项拒绝输入 | 明确失败，不计为互操作成功；submission_wbtest.mbt |
| D2 | 两项非十进制整数 | 分别验证本库固定预期与自身往返；上游结果由真实差分工具检查 |
| X1 | 140个原创固定/生成输入 | 对比双方接受/拒绝和树；110个共同范围输入通过双向写出/读取 |

执行moon test运行本库固定验收用例。运行tools/Get-Upstream.ps1、tools/Build-Oracle.ps1及node tools/differential.mjs复现真实上游验证。适配器使用17位浮点精度、科学记数法和默认十进制写出格式。完整结果见COMPATIBILITY.md与evidence/differential-windows.json。
