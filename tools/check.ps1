$ErrorActionPreference = 'Stop'

$packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'

function Find-Tool([string]$name) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $exe = Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter "$name.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $exe) { throw "$name.exe를 찾지 못했습니다." }
    return $exe.FullName
}

$rojo = Find-Tool 'rojo'
$selene = Find-Tool 'selene'
$stylua = Find-Tool 'stylua'

& $stylua --check src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $selene src
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $rojo build default.project.json -o PorcelainTacticsPrototype.rbxlx
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 시스템 모듈(육성·아이템·명예·사망·탑 보상·능력 카드·룬·기도)의 수치를
# Studio 없이 Lune으로 실행해 사양과 대조한다.
# Lune이 없으면 건너뛴다 (winget install Lune.Lune 으로 설치).
$lune = Get-Command 'lune' -ErrorAction SilentlyContinue
if (-not $lune) {
    $luneExe = Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter 'lune.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($luneExe) { $lune = $luneExe.FullName }
} else {
    $lune = $lune.Source
}

if ($lune) {
    & $lune run tools/run_system_tests.luau
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "[check] Lune이 없어 시스템 테스트를 건너뜁니다. winget install Lune.Lune"
}

exit 0

