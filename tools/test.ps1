$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$godot = Get-ChildItem -LiteralPath 'D:\Developments\Godot' -Filter 'Godot_v*-stable_win64_console.exe' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1 -ExpandProperty FullName

if (-not $godot) {
    throw '未找到 Godot console 可执行文件。'
}

function Invoke-Godot {
    param([string[]]$Arguments)
    & $godot --path $project @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Godot 命令失败，退出码 $LASTEXITCODE"
    }
}

Invoke-Godot @('--headless', '--import')
Invoke-Godot @('--headless', '--check-only', '--script', 'res://scripts/main.gd')
Invoke-Godot @('--headless', '--script', 'res://tools/test_rules.gd')
Invoke-Godot @('--headless', '--script', 'res://tools/test_integration.gd')
Invoke-Godot @('--headless', '--quit-after', '5')
Write-Host '全部检查通过。'
