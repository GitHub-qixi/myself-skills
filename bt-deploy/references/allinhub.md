# AllinHub 发布实例

适用于已核实目标为原 AllinHub 服务的发布。首次上线走通用流程，后续优先复用现有进程和反代。下列值来自历史环境，操作前以本次预检为准。

- 已登录的 Codex 内置浏览器进入宝塔「文件」及「终端」。上传目录为 /opt/allinhub-stage，执行文件为 /opt/allinhub/allinhub，systemd 单元为 allinhub.service。
- 本地执行项目的前端构建，再将生成的 web/dist 嵌入 Go 二进制。历史使用 npm --prefix web run build 和 GOOS=linux、GOARCH=amd64、CGO_ENABLED=0。构建前确认依赖及目标架构，发布版本用提交号标识，有未提交代码时注明本地工作区构建并加时间戳。
- 后端监听 127.0.0.1:13000。优先用项目支持的配置项。旧版本仅支持端口时，历史构建使用临时 Go overlay 修改监听地址，并将差异记入发布记录。
- 首次上线曾用 SQLite 一致快照迁移，并通过宝塔独立反代申请站点 HTTPS。升级时继续使用 /opt/allinhub/data/new-api.db 和现有运行配置。发布包内仅有二进制。切换前后对比数据库文件 inode，执行只读 PRAGMA quick_check。inode 一致只证明文件未替换，启动迁移仍需单独评估。
- 可使用 [二进制发布脚本](../scripts/release-binary.sh)。包内文件名为 app，健康检查脚本接收版本参数。用 curl 请求 127.0.0.1:13000/api/status，解析 JSON 并校验 success 为 true 且 data.version 与参数完全一致。切换后公网再核验同一版本、首页和静态资源。
- 登录和上游调用按授权及可用测试账户验收。历史 Windows 测试中曾因日志仍被占用导致临时文件清理失败，若复现则区分清理错误与业务断言失败，并记录实际结果。
