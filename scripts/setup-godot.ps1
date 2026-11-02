$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$toolDirectory = Join-Path $projectRoot '.cache\godot'
New-Item -ItemType Directory -Force -Path $toolDirectory | Out-Null
$engine = Join-Path $toolDirectory 'Godot_v4.7.2-stable_win64_console.exe'
$release = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable'
if (-not (Test-Path -LiteralPath $engine)) {
    $archive = Join-Path $toolDirectory 'godot.zip'
    $sums = Join-Path $toolDirectory 'SHA512-SUMS.txt'
    Invoke-WebRequest -Uri "$release/Godot_v4.7.2-stable_win64.exe.zip" -OutFile $archive
    Invoke-WebRequest -Uri "$release/SHA512-SUMS.txt" -OutFile $sums
    $expected = ((Get-Content -LiteralPath $sums | Where-Object { $_ -match 'Godot_v4.7.2-stable_win64.exe.zip$' }) -split '\s+')[0]
    if (-not $expected -or (Get-FileHash -LiteralPath $archive -Algorithm SHA512).Hash -ne $expected) { throw 'Godot checksum mismatch.' }
    Expand-Archive -LiteralPath $archive -DestinationPath $toolDirectory -Force
}
if (-not (Test-Path -LiteralPath (Join-Path $toolDirectory 'templates\web_release.zip')) -or
    -not (Test-Path -LiteralPath (Join-Path $toolDirectory 'templates\windows_release_x86_64.exe'))) {
    & (Join-Path $projectRoot '.venv\Scripts\python.exe') (Join-Path $PSScriptRoot 'fetch-godot-templates.py')
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare Godot export templates.' }
}
& $engine --version
