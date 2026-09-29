# 편집기를 다시 빌드해서 Cloudflare Pages의 **같은 프로젝트**에 올린다.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\deploy.ps1
#
# 프로젝트를 새로 만들 필요가 없다 — 같은 이름으로 올리면 새 배포로 덮이고
# 주소(porcelain-editor.pages.dev)도 그대로다.
#
# 처음 한 번만 로그인 창이 뜬다(브라우저에서 Cloudflare 계정 승인).
# 그 뒤로는 이 스크립트 한 줄이면 끝이다.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

# Cloudflare Pages 프로젝트 이름과 실제 주소.
#
# 주소는 프로젝트 이름 그대로가 아니라 뒤에 짧은 꼬리가 붙는다(ang → ang-7sz).
# 배포할 때마다 바뀌지는 않는다. 프로젝트를 새로 만들면 **둘 다** 고쳐야 한다 —
# 다만 이름을 바꾸면 주소도 바뀌어 동업자들이 쓰던 링크가 끊기므로 그대로 두는 게 낫다.
$project = 'ang'
$domain = 'ang-7sz.pages.dev'

# 1) 최신 소스로 편집기 HTML을 다시 만든다.
$packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
$lune = (Get-Command 'lune' -ErrorAction SilentlyContinue).Source
if (-not $lune) {
    $found = Get-ChildItem -LiteralPath $packageRoot -Recurse -Filter 'lune.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $found) { throw 'lune.exe를 찾지 못했습니다.' }
    $lune = $found.FullName
}
& $lune run tools/build_config_editor.luau
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# 2) Pages는 폴더를 올린다. 기본 문서 이름이 index.html이어야 한다.
New-Item -ItemType Directory -Force -Path deploy | Out-Null
Copy-Item config_editor.html deploy\index.html -Force

# 3) 올린다. --project-name 이 같으면 늘 같은 주소에 새 배포가 얹힌다.
npx --yes wrangler@latest pages deploy deploy --project-name=$project --commit-dirty=true
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ''
Write-Host "[deploy] https://$domain 에 올렸습니다. (동업자는 새로고침 한 번)"
