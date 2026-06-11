param($Port = 8080)

$api = "http://localhost:$Port"
$last_tokens = 0
$last_time = Get-Date

$server_was_up = $false
while ($true) {
    $proc = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
    if (-not $proc) {
        if ($server_was_up) {
            Write-Host "llama-server exited. Closing monitor..." -ForegroundColor Red
            Start-Sleep -Seconds 1
            break
        }
        Start-Sleep -Seconds 2
        continue
    }
    $server_was_up = $true
    Clear-Host
    Write-Host "====== llama.cpp Monitor ======" -ForegroundColor Cyan
    Write-Host ""

    # Model info
    try {
        $models = Invoke-RestMethod -Uri "$api/v1/models" -TimeoutSec 3 -ErrorAction Stop
        $m = $models.data[0]
        Write-Host "Model: " -NoNewline; Write-Host "$($m.id)" -ForegroundColor Yellow
        Write-Host "Context: $($m.meta.n_ctx) / $($m.meta.n_ctx_train) (cur/train)" -ForegroundColor Gray

        # Detect MTP and vision from server process command line
        $svc = Get-CimInstance Win32_Process -Filter "name='llama-server.exe'" -ErrorAction SilentlyContinue
        if ($svc) {
            $cl = $svc.CommandLine
            $mtp = if ($cl -match "--spec-type") { "yes" } else { "no" }
            $mmproj = if ($cl -match "--mmproj") { "yes" } else { "no" }
            Write-Host "MTP: $mtp | Vision: $mmproj" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Model: " -NoNewline; Write-Host "offline" -ForegroundColor Red
    }

    # Slots / generation stats
    try {
        $slots = Invoke-RestMethod -Uri "$api/slots" -TimeoutSec 3 -ErrorAction Stop
        $active = $slots | Where-Object { $_.state -ne "idle" }
        if ($active) {
            Write-Host "Generating: " -NoNewline; Write-Host "yes" -ForegroundColor Green
            foreach ($s in $active) {
                $t = $s.cache_tokens_count
                if ($s.n_prompt_tokens_processed -and $s.n_prompt_tokens_processed -gt 0) {
                    $pct = [math]::Round($s.progress * 100, 0)
                    Write-Host "  Prompt: $($s.n_prompt_tokens_processed)/$($s.n_prompt_tokens) ($pct%)" -ForegroundColor Yellow
                }
                $now = Get-Date
                $elapsed = ($now - $last_time).TotalSeconds
                if ($last_tokens -gt 0 -and $elapsed -gt 0 -and $t -gt $last_tokens) {
                    $tps = [math]::Round(($t - $last_tokens) / $elapsed, 1)
                    Write-Host "  Tok/s: $tps" -ForegroundColor Green
                }
                $last_tokens = $t
                $last_time = $now
            }
        } else {
            Write-Host "Generating: " -NoNewline; Write-Host "idle" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Server: " -NoNewline; Write-Host "offline" -ForegroundColor Red
    }

    # Connected clients
    try {
        $raw = netstat -n 2>&1
        $conns = $raw | Select-String ":$Port " | Where-Object { $_ -match "ESTABLISHED" }
        $remote = $conns | ForEach-Object {
            $parts = $_ -split "\s+"
            if ($parts.Count -ge 4) {
                $foreign = $parts[3]
                $addr = $foreign -replace ":\d+$", ""
                if ($addr -ne "127.0.0.1" -and $addr -ne "::1") { $addr }
            }
        } | Select-Object -Unique
        if ($remote) {
            Write-Host "Clients: " -NoNewline; Write-Host "$($remote -join ', ')" -ForegroundColor Green
        }
    } catch { Write-Host "Clients: error" -ForegroundColor Red }

    Write-Host ""

    # GPU
    try {
        $gpu = nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>$null
        foreach ($line in $gpu) {
            $parts = $line -split ", "
            Write-Host "GPU $($parts[0]): $($parts[1])" -ForegroundColor Magenta
            Write-Host "  Usage: $($parts[2])% | VRAM: $($parts[3])/$($parts[4]) MB | Temp: $($parts[5])C"
        }
    } catch { Write-Host "GPU: N/A" -ForegroundColor Red }

    Write-Host ""

    # CPU & RAM
    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if (-not $cpu) { $cpu = 0 }
    $os = Get-CimInstance Win32_OperatingSystem
    $ram_pct = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)
    $ram_gb = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB, 1)
    $ram_total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)

    Write-Host "CPU: $cpu% | RAM: ${ram_gb}/${ram_total} GB ($ram_pct%)" -ForegroundColor Yellow

    # llama-server process
    $proc = Get-Process -Name "llama-server" -ErrorAction SilentlyContinue
    if ($proc) {
        $proc_mb = [math]::Round(($proc.WorkingSet64 | Measure-Object -Sum).Sum / 1MB, 0)
        $proc_cpu = [math]::Round(($proc.CPU | Measure-Object -Sum).Sum, 0)
        Write-Host "Process: ${proc_mb}MB | CPU time: ${proc_cpu}s" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Refreshing every 2s... (Ctrl+C to close)" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}
