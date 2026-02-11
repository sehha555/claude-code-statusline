# claude-code-statusline
# 顯示 Claude Code 即時 session 資訊 + 訂閱方案用量監控
# https://github.com/sehha555/claude-code-statusline

# 從 stdin 讀取 JSON（相容 pipeline 和 -Command 模式）
$rawLines = @()
try {
    while ($null -ne ($line = [Console]::In.ReadLine())) {
        $rawLines += $line
    }
} catch {}
$raw = $rawLines -join "`n"
if (-not $raw) { $raw = $input | Out-String }

$data = $raw | ConvertFrom-Json

# ===== 當前 Session 資料（從 statusline API） =====

# 模型
$model = $data.model.display_name

# 費用
$cost = [double]($data.cost.total_cost_usd)
$costFmt = '$' + ('{0:N2}' -f $cost)

# Context window
$pct = [math]::Floor([double]($data.context_window.used_percentage))
$filled = [math]::Floor($pct / 10)
$empty = 10 - $filled
$bar = '#' * $filled + '-' * $empty

# Tokens
$inTokens = [double]($data.context_window.total_input_tokens)
$outTokens = [double]($data.context_window.total_output_tokens)
$totalTokens = $inTokens + $outTokens

# Token 格式化 (k/M)
function Format-Tokens($n) {
    if ($n -ge 1000000) { return '{0:N1}M' -f ($n / 1000000) }
    elseif ($n -ge 1000) { return '{0:N1}k' -f ($n / 1000) }
    else { return [string][math]::Floor($n) }
}

$outFmt = Format-Tokens $outTokens

# 速率 (tokens/sec)
$apiMs = [double]($data.cost.total_api_duration_ms)
if ($apiMs -gt 0) {
    $tps = [math]::Round($outTokens / ($apiMs / 1000), 1)
    $tpsFmt = "${tps}t/s"
} else {
    $tpsFmt = "-"
}

# 時間
$durationMs = [double]($data.cost.total_duration_ms)
$mins = [math]::Floor($durationMs / 60000)
$secs = [math]::Floor(($durationMs % 60000) / 1000)

# Context 顏色警示標記
if ($pct -ge 90) { $warn = "(!)" }
elseif ($pct -ge 70) { $warn = "(*)" }
else { $warn = "" }

# ===== 訂閱方案監控（從 stats-cache.json + config） =====

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$configFile = Join-Path $claudeDir "plan-config.json"
$cacheFile = Join-Path $claudeDir "stats-cache.json"

# 讀取方案設定（預設 pro）
$plan = "pro"
$planLimits = @{
    "pro"   = @{ "outTokens" = 19000;  "cost" = 18.0;  "msgs" = 250;  "label" = "Pro" }
    "max5"  = @{ "outTokens" = 88000;  "cost" = 35.0;  "msgs" = 1000; "label" = "Max5" }
    "max20" = @{ "outTokens" = 220000; "cost" = 140.0; "msgs" = 2000; "label" = "Max20" }
}

if (Test-Path $configFile) {
    try {
        $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
        if ($cfg.plan -and $planLimits.ContainsKey($cfg.plan)) {
            $plan = $cfg.plan
        }
    } catch {}
}

$limit = $planLimits[$plan]
$planLabel = $limit["label"]

# 讀取今日 token 使用量（從 stats-cache.json）
$todayStr = (Get-Date).ToString("yyyy-MM-dd")
$todayOutTokens = 0
$todayMsgs = 0
$todaySessions = 0

if (Test-Path $cacheFile) {
    try {
        $cache = Get-Content $cacheFile -Raw | ConvertFrom-Json

        # 每日 output tokens
        foreach ($day in $cache.dailyModelTokens) {
            if ($day.date -eq $todayStr) {
                $props = $day.tokensByModel.PSObject.Properties
                foreach ($p in $props) {
                    $todayOutTokens += [double]$p.Value
                }
                break
            }
        }

        # 每日 message count
        foreach ($day in $cache.dailyActivity) {
            if ($day.date -eq $todayStr) {
                $todayMsgs = [int]$day.messageCount
                $todaySessions = [int]$day.sessionCount
                break
            }
        }
    } catch {}
}

# 加上當前 session 的 output tokens（可能還沒寫入 cache）
$todayOutWithSession = $todayOutTokens + $outTokens

# 格式化今日用量
$todayFmt = Format-Tokens $todayOutWithSession

# 用量百分比（相對方案 limit）
$tokenLimit = $limit["outTokens"]
$usagePct = if ($tokenLimit -gt 0) {
    [math]::Min([math]::Floor(($todayOutWithSession / $tokenLimit) * 100), 999)
} else { 0 }

# 用量 bar（5 格簡化版）
$uFilled = [math]::Min([math]::Floor($usagePct / 20), 5)
$uEmpty = 5 - $uFilled
$uBar = '#' * $uFilled + '-' * $uEmpty

# 用量警示
$uWarn = ""
if ($usagePct -ge 90) { $uWarn = "(!)" }
elseif ($usagePct -ge 70) { $uWarn = "(*)" }

# ===== 組裝輸出 =====
$limitFmt = Format-Tokens $tokenLimit

Write-Host "$model | $bar ${pct}%${warn} | $costFmt | ${outFmt} out ${tpsFmt} | ${mins}m${secs}s | $planLabel $uBar ${todayFmt}/${limitFmt} ${usagePct}%${uWarn}"
