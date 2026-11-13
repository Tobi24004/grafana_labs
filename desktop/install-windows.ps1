<#
    Tạo shortcut "Network Operations Center" trong Start Menu và ngoài Desktop,
    trỏ thẳng tới Edge/Chrome ở chế độ --app kèm icon riêng.

    Cài :  powershell -ExecutionPolicy Bypass -File desktop\install-windows.ps1
    Gỡ  :  powershell -ExecutionPolicy Bypass -File desktop\install-windows.ps1 -Remove
#>
param([switch]$Remove)

$ErrorActionPreference = 'Stop'
$Name = 'Network Operations Center'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Split-Path -Parent $Here
$Page = Join-Path $Root 'index.html'
$Icon = Join-Path $Here 'icon.ico'

$Targets = @(
    (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\$Name.lnk"),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) "$Name.lnk")
)

if ($Remove) {
    foreach ($t in $Targets) { if (Test-Path $t) { Remove-Item $t -Force; Write-Host "Da xoa: $t" } }
    Write-Host 'Da go shortcut.'
    exit 0
}

if (-not (Test-Path $Page)) { throw "Khong tim thay $Page" }

$Candidates = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LocalAppData\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe"
)
$Browser = $Candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Browser) { throw 'Khong tim thay Edge, Chrome hay Brave. Cai mot trong so do roi chay lai.' }

$Url = 'file:///' + ($Page -replace '\\', '/')
$Shell = New-Object -ComObject WScript.Shell

foreach ($t in $Targets) {
    $dir = Split-Path -Parent $t
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $lnk = $Shell.CreateShortcut($t)
    $lnk.TargetPath       = $Browser
    $lnk.Arguments        = "--app=`"$Url`" --window-size=1480,920"
    $lnk.WorkingDirectory = $Root
    $lnk.Description      = 'Mo phong Grafana cho ha tang mang - du lieu sinh trong may, khong ket noi he thong that'
    if (Test-Path $Icon) { $lnk.IconLocation = "$Icon,0" }
    $lnk.Save()
    Write-Host "Da tao: $t"
}

Write-Host ''
Write-Host "Xong. Go `"$Name`" o Start Menu, hoac bam shortcut ngoai Desktop."
Write-Host "Trinh duyet dung lam khung app: $Browser"
