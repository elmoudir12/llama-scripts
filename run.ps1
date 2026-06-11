$env:GGML_CUDA_ENABLE_UNSAFE_MATH = "1"
$BIN = "C:\Users\AZIZ\Desktop\llama.cpp\build\bin"

$GW_MODEL = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-31B-it-qat-UD-Q4_K_XL\gemma-4-31B-it-qat-UD-Q4_K_XL.gguf"
$GW_MMPROJ = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-31B-it-qat-UD-Q4_K_XL\mmproj-BF16.gguf"
$GW_MTP = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-31B-it-qat-UD-Q4_K_XL\gemma-4-31B-it-Q4_0-MTP.gguf"

$QW_MODEL = "C:\Users\AZIZ\Desktop\llama.cpp\models\Qwen3.6-27B-uncensored-heretic-v2-Native-MTP-Preserved-Q4_K_M.gguf"
$QW_MMPROJ = "C:\Users\AZIZ\Desktop\llama.cpp\models\Qwen3.6-27B-UD-Q5_K_L-mmproj-BF16.gguf"

$G12_MODEL = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-12B-it-qat-UD-Q4_K_XL\gemma-4-12B-it-qat-UD-Q4_K_XL.gguf"
$G12_MMPROJ = "C:\Users\AZIZ\Desktop\llama.cpp\models\mmproj-gemma-4-12B-BF16.gguf"
$G12_MTP = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-12B-it-qat-UD-Q4_K_XL\gemma-4-12B-it-Q4_0-MTP.gguf"

$NM_MODEL = "C:\Users\AZIZ\Desktop\llama.cpp\models\North-Mini-Code-1.0-UD-IQ4_NL\North-Mini-Code-1.0-UD-IQ4_NL.gguf"

function Get-LanIP {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|Virtual|Bluetooth|Docker|vEthernet" -and $_.PrefixOrigin -eq "Dhcp" } | Select-Object -First 1).IPAddress
    if (-not $ip) { $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch "Loopback|Virtual|Bluetooth|Docker" } | Select-Object -First 1).IPAddress }
    return $ip
}

function Start-Monitor {
    Start-Process "C:\Users\AZIZ\Desktop\llama.cpp\monitor.bat"
}

function Draw-Menu($title, $items, $sel) {
    Write-Host "$title" -ForegroundColor Cyan
    foreach ($item in $items) {
        $num = ($item -split '\.')[0].Trim()
        $line = "  $item"
        if ($sel -eq $num) { Write-Host "$line  <<<" -ForegroundColor Green }
        else { Write-Host "$line" }
    }
}

function Read-Keyed($title, $items) {
    $h = $items.Count + 2
    $y = [System.Console]::CursorTop
    $blank = $true
    while ($true) {
        [System.Console]::SetCursorPosition(0, $y)
        foreach ($i in 1..$h) { Write-Host "".PadRight(50) }
        [System.Console]::SetCursorPosition(0, $y)
        if ($blank) { Draw-Menu $title $items "" }
        else { Draw-Menu $title $items $buf }
        Write-Host "Select: " -NoNewline
        if ($blank) { Write-Host "      " -NoNewline }
        else {
            foreach ($c in $buf.ToCharArray()) { Write-Host $c -NoNewline -ForegroundColor Cyan }
        }

        $key = [System.Console]::ReadKey($true)
        if ($key.Key -eq "Enter" -and -not $blank) {
            if (($items | Select-String "^$buf\.")) { Write-Host ""; return $buf }
            $blank = $true; $buf = ""; continue
        }
        if ($key.Key -eq "Escape") { Write-Host ""; return "" }
        if ($key.Key -eq "Backspace" -and -not $blank) {
            $buf = $buf.Substring(0, $buf.Length - 1)
            if ($buf.Length -eq 0) { $blank = $true }
        }
        elseif ($key.KeyChar -ge '0' -and $key.KeyChar -le '9') {
            if ($blank) { $buf = ""; $blank = $false }
            $buf = $buf + [string]$key.KeyChar
        }
    }
}

do {
    $m = Read-Keyed "=== Pick Model ===" @(
        "1. Gemma 4 31B (external MTP draft)",
        "2. Qwen 3.6 27B (native MTP)",
        "3. Gemma 4 12B (external MTP draft)",
        "4. North Mini Code 1.0 (MoE code model)",
        "5. Check for llama.cpp updates",
        "0. Quit"
    )
    if ($m -eq "0" -or $m -eq "") { break }

    if ($m -eq "5") {
        Write-Host "Checking for updates..." -ForegroundColor Yellow
        $current = & "$BIN\llama-server.exe" --version 2>&1 | Select-Object -First 1
        Write-Host "Current: $current" -ForegroundColor Cyan
        try {
            $reply = Invoke-WebRequest -Uri "https://api.github.com/repos/ggerganov/llama.cpp/commits?sha=master&per_page=1" -UseBasicParsing
            $latest = ($reply | ConvertFrom-Json)[0].sha.Substring(0,9)
            Write-Host "Latest:  commit $latest" -ForegroundColor Cyan
            if ($current -match $latest) {
                Write-Host "Already up to date!" -ForegroundColor Green
            } else {
                $ans = Read-Host "Update available. Pull and rebuild? (y/n)"
                if ($ans -eq "y") {
                    Get-Process -Name "llama-server" -ErrorAction SilentlyContinue | Stop-Process -Force
                    Push-Location "C:\Users\AZIZ\Desktop\llama.cpp"
                    git pull
                    $vs = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -latest -property installationPath 2>$null
                    cmd.exe /c "`"$vs\VC\Auxiliary\Build\vcvars64.bat`" && cd /d C:\Users\AZIZ\Desktop\llama.cpp && cmake -B build -G Ninja -DGGML_CUDA=ON -DGGML_CUDA_FA=ON -DCMAKE_CUDA_FLAGS=-allow-unsupported-compiler && cmake --build build -j --target llama-server llama-cli"
                    $ok = $LASTEXITCODE -eq 0
                    Pop-Location
                    if ($ok) { Write-Host "Rebuild succeeded!" -ForegroundColor Green }
                    else { Write-Host "Rebuild failed (exit code $LASTEXITCODE). Check build output above." -ForegroundColor Red }
                }
            }
        } catch {
            Write-Host "Failed to check updates: $_" -ForegroundColor Red
        }
        Write-Host "Press any key to return..." -NoNewline
        $null = [System.Console]::ReadKey($true)
        continue
    }

    if ($m -eq "2") {
        $MODEL = $QW_MODEL
        $MMPROJ = $QW_MMPROJ
        $FULL = "-m `"$MODEL`" --mmproj `"$MMPROJ`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 20"
        $NOMTP = $FULL
        $TEXT = "-m `"$MODEL`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 20"
    } elseif ($m -eq "3") {
        $MODEL = $G12_MODEL
        $MMPROJ = $G12_MMPROJ
        $FULL = "-m `"$MODEL`" --mmproj `"$MMPROJ`" --jinja --spec-type draft-mtp --spec-draft-model `"$G12_MTP`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $NOMTP = "-m `"$MODEL`" --mmproj `"$MMPROJ`" --jinja -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $TEXT = "-m `"$MODEL`" --jinja -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
    } elseif ($m -eq "4") {
        $MODEL = $NM_MODEL
        $MMPROJ = ""
        $FULL = "-m `"$MODEL`" --jinja -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95"
        $NOMTP = $FULL
        $TEXT = $FULL
    } else {
        $MODEL = $GW_MODEL
        $MMPROJ = $GW_MMPROJ
        $FULL = "-m `"$MODEL`" --spec-type draft-mtp --spec-draft-model `"$GW_MTP`" --spec-draft-n-max 4 -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $NOMTP = "-m `"$MODEL`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $TEXT = "-m `"$MODEL`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
    }

    do {
        if ($m -eq "2") {
            $choice = Read-Keyed "=== Qwen 3.6 27B ===" @(
                "1. Chat (text only)",
                "2. Chat with image",
                "3. Server mode (API)",
                "4. Server mode (API, no vision)",
                "5. Custom prompt",
                "0. Back to model picker"
            )
        } elseif ($m -eq "3") {
            $choice = Read-Keyed "=== Gemma 4 12B ===" @(
                "1. Chat (with MTP)",
                "2. Chat with image (with MTP)",
                "3. Server mode (API, with MTP)",
                "4. Server mode (API, no MTP)",
                "5. Custom prompt",
                "0. Back to model picker"
            )
        } elseif ($m -eq "4") {
            $choice = Read-Keyed "=== North Mini Code 1.0 ===" @(
                "1. Chat",
                "2. Server mode (API)",
                "3. Custom prompt",
                "0. Back to model picker"
            )
        } else {
            $choice = Read-Keyed "=== Gemma 4 31B ===" @(
                "1. Chat (with MTP)",
                "2. Chat with image (with MTP)",
                "3. Server mode (with MTP, no vision)",
                "4. Server mode (with MTP, vision)",
                "5. Server mode (no MTP, no vision)",
                "6. Custom prompt",
                "0. Back to model picker"
            )
        }
        if ($choice -eq "0" -or $choice -eq "") { break }

        switch ($choice) {
            "1" {
                if ($m -eq "2") { & "$BIN\llama-cli.exe" $TEXT.Split(" ") "--chat-template" "qwen" }
                elseif ($m -eq "4") { & "$BIN\llama-cli.exe" $FULL.Split(" ") }
                else { & "$BIN\llama-cli.exe" $FULL.Split(" ") "--chat-template" "gemma" }
            }
            "2" {
                if ($m -eq "1") {
                    $img = Read-Host "Path to image"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") "--mmproj" $GW_MMPROJ "--image" $img "--chat-template" "gemma"
                } elseif ($m -eq "4") {
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") --port 8080 --host 0.0.0.0
                } else {
                    $img = Read-Host "Path to image"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") "--image" $img
                }
            }
            "3" {
                if ($m -eq "4") {
                    $prompt = Read-Host "Enter prompt"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt
                } else {
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") --port 8080 --host 0.0.0.0
                }
            }
            "4" {
                if ($m -eq "1") {
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") "--mmproj" $GW_MMPROJ --port 8080 --host 0.0.0.0
                } else {
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    if ($m -eq "2") { & "$BIN\llama-server.exe" $TEXT.Split(" ") --port 8080 --host 0.0.0.0 }
                    else { & "$BIN\llama-server.exe" $NOMTP.Split(" ") --port 8080 --host 0.0.0.0 }
                }
            }
            "5" {
                if ($m -eq "1") {
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $NOMTP.Split(" ") --port 8080 --host 0.0.0.0
                } else {
                    $prompt = Read-Host "Enter prompt"
                    if ($m -eq "2") { & "$BIN\llama-cli.exe" $TEXT.Split(" ") -p $prompt }
                    else { & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt }
                }
            }
            "6" {
                $prompt = Read-Host "Enter prompt"
                & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt
            }
        }
        Write-Host ""
    } while ($true)
} while ($true)
