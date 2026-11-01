# 显存看门狗：专治「模型不报错但掉速」
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File vram_watch.ps1
#   powershell -ExecutionPolicy Bypass -File vram_watch.ps1 -ThresholdMB 600 -IntervalSec 5
#
# 逻辑：
#   每 N 秒查一次显存；若「已用显存突然下降超过阈值」或「剩余低于阈值」，
#   打印时间与占用进程——因为 8GB 卡掉速的第一元凶永远是有东西在抢显存。

param(
    [int]$ThresholdMB = 500,   # 剩余显存低于此值即报警
    [int]$IntervalSec = 5,
    [int]$FlushMB     = 800    # 已用显存单次下跌超过此值，视为有进程退出
)

$lastUsed = $null
Write-Host "显存看门狗启动：剩余 < ${ThresholdMB}MB 或 占用骤降 ${FlushMB}MB 时报警" -ForegroundColor Cyan
Write-Host "按 Ctrl+C 退出`n"

while ($true) {
    $line = & nvidia-smi --query-gpu=memory.used,memory.free --format=csv,noheader,nounits 2>$null
    if ($line) {
        $parts = $line -split ','
        $used = [int]$parts[0].Trim()
        $free = [int]$parts[1].Trim()
        $ts = Get-Date -Format 'HH:mm:ss'

        if ($free -lt $ThresholdMB) {
            Write-Host "[$ts] ⚠ 剩余显存仅 ${free}MB（已用 ${used}MB）" -ForegroundColor Red
            Write-Host "     占用进程：" -ForegroundColor Yellow
            & nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader |
                ForEach-Object { Write-Host "       $_" -ForegroundColor Yellow }
        }
        elseif ($null -ne $lastUsed -and ($lastUsed - $used) -gt $FlushMB) {
            Write-Host "[$ts] ↓ 显存占用骤降 $($lastUsed - $used)MB（有进程退出或卸载了模型）" -ForegroundColor Magenta
        }
        else {
            Write-Host "[$ts] 已用 ${used}MB / 剩余 ${free}MB" -ForegroundColor DarkGray
        }
        $lastUsed = $used
    }
    Start-Sleep -Seconds $IntervalSec
}
