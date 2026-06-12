$env:GGML_CUDA_ENABLE_UNSAFE_MATH = "1"
$BIN = "C:\Users\AZIZ\Desktop\llama.cpp\build\bin"

$G12U_MODEL = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-12B-it-uncensored-heretic-NVFP4\gemma-4-12B-it-uncensored-heretic-NVFP4.gguf"
$G12U_MMPROJ = "C:\Users\AZIZ\Desktop\llama.cpp\models\gemma-4-12B-it-uncensored-heretic-NVFP4\gemma-4-12B-it-uncensored-heretic-mmproj-BF16.gguf"
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

function Kill-OldServer {
    Get-Process -Name "llama-server" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
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
        "5. Gemma 4 12B uncensored (NVFP4)",
        "6. Check for llama.cpp updates",
        "0. Quit"
    )
    if ($m -eq "0" -or $m -eq "") { break }

    if ($m -eq "6") {
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
        $KV8 = "-m `"$MODEL`" --mmproj `"$MMPROJ`" -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 20 -ctk q8_0 -ctv q8_0"
        $KV4_100K = "-m `"$MODEL`" --mmproj `"$MMPROJ`" -ngl all -fa on -c 100000 --temp 1.0 --top-p 0.95 --top-k 20 -ctk q4_0 -ctv q4_0"
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
    } elseif ($m -eq "5") {
        $MODEL = $G12U_MODEL
        $MMPROJ = $G12U_MMPROJ
        $FULL = "-m `"$MODEL`" --mmproj `"$MMPROJ`" --jinja -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $NOMTP = $FULL
        $TEXT = "-m `"$MODEL`" --jinja -ngl all -fa on -c 70000 --temp 1.0 --top-p 0.95 --top-k 64"
        $KV8_128K = "-m `"$MODEL`" --mmproj `"$MMPROJ`" --jinja -ngl all -fa on -c 128000 --temp 1.0 --top-p 0.95 --top-k 64 -ctk q8_0 -ctv q8_0"
        $KV4_256K = "-m `"$MODEL`" --mmproj `"$MMPROJ`" --jinja -ngl all -fa on -c 256000 --temp 1.0 --top-p 0.95 --top-k 64 -ctk q4_0 -ctv q4_0"
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
                "3. Server mode (API, default)",
                "4. Server mode (API, Q8_0 KV @70k) -- recommended",
                "5. Server mode (API, Q4_0 KV @100k)",
                "6. Server mode (API, no vision)",
                "7. Custom prompt",
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
        } elseif ($m -eq "5") {
            $choice = Read-Keyed "=== Gemma 4 12B uncensored ===" @(
                "1. Chat",
                "2. Chat with image",
                "3. Server mode (API)",
                "4. Server mode (API, no vision)",
                "5. Server mode (API, Q8_0 KV @128k)",
                "6. Server mode (API, Q4_0 KV @256k)",
                "7. Custom prompt",
                "0. Back to model picker"
            )
        } else {
            $choice = Read-Keyed "=== Gemma 4 31B ===" @(
                "1. Chat (with MTP)",
                "2. Chat (no MTP)",
                "3. Chat with image (with MTP)",
                "4. Chat with image (no MTP)",
                "5. Server mode (with MTP, no vision)",
                "6. Server mode (with MTP, vision)",
                "7. Server mode (no MTP, no vision)",
                "8. Server mode (no MTP, vision)",
                "9. Custom prompt",
                "0. Back to model picker"
            )
        }
        if ($choice -eq "0" -or $choice -eq "") { break }

        switch ($choice) {
            "1" {
                if ($m -eq "2") { & "$BIN\llama-cli.exe" $TEXT.Split(" ") "--chat-template" "qwen" }
                elseif ($m -eq "5") { & "$BIN\llama-cli.exe" $TEXT.Split(" ") "--jinja" }
                elseif ($m -eq "4") { & "$BIN\llama-cli.exe" $FULL.Split(" ") }
                else { & "$BIN\llama-cli.exe" $FULL.Split(" ") "--chat-template" "gemma" }
            }
            "2" {
                if ($m -eq "1") {
                    & "$BIN\llama-cli.exe" $NOMTP.Split(" ") "--jinja"
                } elseif ($m -eq "5") {
                    $img = Read-Host "Path to image"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") "--image" $img
                } elseif ($m -eq "4") {
                    Kill-OldServer
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
                if ($m -eq "1") {
                    $img = Read-Host "Path to image"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") "--mmproj" $GW_MMPROJ "--image" $img "--chat-template" "gemma"
                } elseif ($m -eq "5") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") --port 8080 --host 0.0.0.0
                } elseif ($m -eq "4") {
                    $prompt = Read-Host "Enter prompt"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt
                } else {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") --port 8080 --host 0.0.0.0
                }
            }
            "4" {
                if ($m -eq "1") {
                    $img = Read-Host "Path to image"
                    & "$BIN\llama-cli.exe" $NOMTP.Split(" ") "--mmproj" $GW_MMPROJ "--image" $img "--jinja"
                } elseif ($m -eq "5") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $TEXT.Split(" ") --port 8080 --host 0.0.0.0
                } elseif ($m -eq "2") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    Write-Host "KV cache: Q8_0 | Context: 70k (recommended)" -ForegroundColor Yellow
                    & "$BIN\llama-server.exe" $KV8.Split(" ") --port 8080 --host 0.0.0.0
                } else {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    if ($m -eq "2") { & "$BIN\llama-server.exe" $TEXT.Split(" ") --port 8080 --host 0.0.0.0 }
                    else { & "$BIN\llama-server.exe" $NOMTP.Split(" ") --port 8080 --host 0.0.0.0 }
                }
            }
            "5" {
                if ($m -eq "1") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") --batch-size 1024 --port 8080 --host 0.0.0.0
                } elseif ($m -eq "5") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    Write-Host "KV cache: Q8_0 | Context: 128k" -ForegroundColor Yellow
                    & "$BIN\llama-server.exe" $KV8_128K.Split(" ") --port 8080 --host 0.0.0.0
                } elseif ($m -eq "2") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    Write-Host "KV cache: Q4_0 | Context: 100k" -ForegroundColor Yellow
                    & "$BIN\llama-server.exe" $KV4_100K.Split(" ") --port 8080 --host 0.0.0.0
                } else {
                    $prompt = Read-Host "Enter prompt"
                    if ($m -eq "2") { & "$BIN\llama-cli.exe" $TEXT.Split(" ") -p $prompt }
                    else { & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt }
                }
            }
            "6" {
                if ($m -eq "1") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $FULL.Split(" ") "--mmproj" $GW_MMPROJ --batch-size 1024 --port 8080 --host 0.0.0.0
                } elseif ($m -eq "5") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    Write-Host "KV cache: Q4_0 | Context: 256k" -ForegroundColor Yellow
                    & "$BIN\llama-server.exe" $KV4_256K.Split(" ") --port 8080 --host 0.0.0.0
                } elseif ($m -eq "2") {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    Write-Host "Mode: text only (no vision)" -ForegroundColor Gray
                    & "$BIN\llama-server.exe" $TEXT.Split(" ") --port 8080 --host 0.0.0.0
                } else {
                    $prompt = Read-Host "Enter prompt"
                    & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt
                }
            }
            "7" {
                if ($m -eq "2") {
                    $prompt = Read-Host "Enter prompt"
                    & "$BIN\llama-cli.exe" $TEXT.Split(" ") -p $prompt
                } elseif ($m -eq "5") {
                    $prompt = Read-Host "Enter prompt"
                    & "$BIN\llama-cli.exe" $TEXT.Split(" ") -p $prompt
                } else {
                    Kill-OldServer
                    Start-Monitor
                    $lan = Get-LanIP
                    Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                    & "$BIN\llama-server.exe" $NOMTP.Split(" ") --batch-size 1024 --port 8080 --host 0.0.0.0
                }
            }
            "8" {
                Kill-OldServer
                Start-Monitor
                $lan = Get-LanIP
                Write-Host "Connect from other devices at: http://$lan`:8080" -ForegroundColor Green
                & "$BIN\llama-server.exe" $NOMTP.Split(" ") "--mmproj" $GW_MMPROJ --batch-size 1024 --port 8080 --host 0.0.0.0
            }
            "9" {
                $prompt = Read-Host "Enter prompt"
                & "$BIN\llama-cli.exe" $FULL.Split(" ") -p $prompt
            }
        }
        Write-Host ""
    } while ($true)
} while ($true)
