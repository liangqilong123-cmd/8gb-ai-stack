# NInfer 长上下文引擎启动脚本（8GB 显存档）
#
# 用途：单模型、长上下文（256K）、视觉走 CPU、MTP 投机解码。
# 用法：
#   powershell -ExecutionPolicy Bypass -File ninfer-start.ps1
# 参数（按需改，或用环境变量覆盖）：
#   $Exe   引擎可执行文件
#   $Model 模型文件（.ninfer / .gguf）
#   $Port  监听端口

param(
    [string]$Exe    = "C:/path/to/ninfer-serve.exe",
    [string]$Model  = "C:/path/to/models/27B-ternary-ptq1.ninfer",
    [int]$Port      = 8091,
    [int]$Context   = 262144,
    [int]$KvPages   = 16000,
    [string]$HostKv = "3328"
)

# ── 环境变量（引擎侧调参，顺序在启动前设置）──────────────────────
$env:NINFER_KV_WINDOW           = "12800"   # 显存内 KV 活跃窗口
$env:NINFER_KV_RETRIEVE         = "8192"    # 按相关性从历史 KV 捞回
$env:NINFER_KV_RING             = "1"       # KV 环形复用
$env:NINFER_KV_REUSE_HOSTBACKED = "1"       # 复用主机端 KV
$env:NINFER_HOST_PAGEABLE       = "1"       # 主机内存可分页（24GB 内存友好）
$env:NINFER_TERNARY_PTQ1_FAST   = "1"       # 三元量化快速路径

Write-Host "启动长上下文引擎 ..." -ForegroundColor Cyan
Write-Host "  模型: $Model"
Write-Host "  端口: $Port   上下文: $Context"

# ── 关键参数说明 ───────────────────────────────────────────────
# --kv-capacity 16000     显存 KV 池页数（8GB 卡的甜点，再大就溢出）
# --kv-dtype rk2v4-e8     KV 量化：K=2bit V=4bit，8GB 卡的关键
# --host-kv-mib 3328      主机端 KV 预留（MB），配合 24GB 内存
# --prefill-chunk 1024    预填充分块，越小越省显存、越慢
# --no-cuda-graph         必须：该引擎在混合精度下开 CUDA Graph 会启动失败
# --vision-cpu            视觉塔走 CPU：省 1.4GB 显存，代价是每图多几秒
#                         （8GB 卡不要用 --vision，装不下）

& $Exe $Model `
    --host 127.0.0.1 --port $Port `
    --kv-capacity $KvPages `
    --kv-dtype rk2v4-e8 `
    --host-kv-mib $HostKv `
    --prefill-chunk 1024 `
    --max-context $Context `
    --no-cuda-graph `
    --vision-cpu `
    --jinja

# 说明：
#   1. 本脚本会阻塞（引擎在前台运行）。窗口关掉 = 服务停止。
#   2. 长驻服务不要交给 IDE / 任务运行器托管，某些自动化工具的进程树
#      会在几分钟后被回收，表现为「服务莫名消失、日志无异常」。
#      要稳定：双击独立窗口启动，或注册为计划任务。
