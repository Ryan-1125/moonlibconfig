# 最终验收入口

## 一键复现

在Windows安装与moonc 0.10.22匹配的SDK、Node.js及MSVC x64工具后，执行：

```powershell
./tools/Verify-Acceptance.ps1
```

默认使用项目.local/toolchains/20261119隔离SDK；可通过-SdkPath传入自己的安装目录。脚本只在当前进程设置MOON_HOME/PATH，结束后恢复，不改全局工具链或编辑器。

脚本依次检查格式、严格编译、三后端构建和测试、API快照、实际ZIP独立消费、固定上游构建、两模式差分、原应用回读及注册表独立消费。任何步骤失败会终止并记录原因，结果写入.local/acceptance/report.json，含源码提交、包版本和每步状态。

## 提交材料对应关系

| 验收要求 | 实际入口 |
| --- | --- |
| 功能与使用说明 | README.md、公开API、examples/service |
| 数值与类型兼容 | docs/COMPATIBILITY.md、tools/differential.mjs --target-profile |
| 多文件范围及来源 | includes.mbt、compatibility_wbtest.mbt |
| 修改后原应用语义 | tools/semantic-edit.mjs，八个独立场景 |
| 核心与资源质量 | 三后端测试、固定种子模糊回归、docs/MAINTENANCE.md |
| 可独立依赖 | Test-Consumer.ps1与Test-RegistryConsumer.ps1分别验证ZIP和注册表 |
| 开源合规 | LICENSE、NOTICE、固定上游授权证据 |
| 平台复现 | GitHub Actions Ubuntu/Windows及compatibility构件 |

报名初审与最终验收分别记录。申报书由参赛者确认后提交，个人申报信息不进入Mooncakes包。技术材料以实际命令、版本和原始报告为依据；运行脚本不自动报名、不重复发布。
