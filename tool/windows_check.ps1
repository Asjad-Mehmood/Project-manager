# The Windows program the way a person gets it, on GitHub's Windows machines (no graphics card):
#   1. install it silently and check what was put where
#   2. the self-check: the installed program does the real jobs on a real Windows (drives, Recycle
#      Bin, copy / move / rename / undo, index and search, a v6.2 settings file)
#   3. open it on a sample project and take a screenshot (it must draw something)
#   4. open it again: the first window comes forward, no second copy
#   5. uninstall it and check nothing is left: program, shortcuts, settings, index, Settings > Apps
#   pwsh tool/windows_check.ps1 installer\ProjectFolderManager-Setup.exe shots
param([Parameter(Mandatory)] [string] $Installer, [string] $Shots = 'shots')
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'ProjectFolderManager'
$exe = Join-Path $dir 'ProjectFolderManager.exe'
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ProjectFolderManager'
$settings = Join-Path $env:APPDATA 'Excel to KML\Project Folder Manager'
$data = Join-Path $env:LOCALAPPDATA 'Excel to KML\Project Folder Manager'
New-Item -ItemType Directory -Force $Shots | Out-Null

function Summary([string] $line) { if ($env:GITHUB_STEP_SUMMARY) { Add-Content $env:GITHUB_STEP_SUMMARY $line } }
function Check($ok, $what) {
  if (-not $ok) { Summary "- ❌ $what"; throw "FAILED: $what" }
  Write-Host "ok  $what"; Summary "- ✅ $what"
}
function WaitFor([scriptblock] $test, [int] $seconds) {
  for ($i = 0; $i -lt $seconds * 2; $i++) { if (& $test) { return $true }; Start-Sleep -Milliseconds 500 }
  return $false
}
function Shot([string] $name) {
  Add-Type -AssemblyName System.Windows.Forms, System.Drawing
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  $bmp = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
  [System.Drawing.Graphics]::FromImage($bmp).CopyFromScreen($screen.Location, [System.Drawing.Point]::Empty, $screen.Size)
  $file = Join-Path $Shots "$name.png"
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $colours = @{}
  for ($x = 0; $x -lt $screen.Width; $x += 23) { for ($y = 0; $y -lt $screen.Height; $y += 19) { $colours[$bmp.GetPixel($x, $y).ToArgb()] = 1 } }
  Write-Host "screenshot: $file ($($screen.Width)x$($screen.Height), $($colours.Count) colours)"
  return $colours.Count
}
Summary '### Project Folder Manager on Windows'

# 1. install
Start-Process -FilePath $Installer -ArgumentList '/S' -Wait
Check (Test-Path $exe) 'installed to %LOCALAPPDATA%\ProjectFolderManager'
foreach ($f in 'flutter_windows.dll', 'data\app.so', 'data\icudtl.dat', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'Uninstall.exe', 'icon.ico') {
  Check (Test-Path (Join-Path $dir $f)) "has $f"
}
Check (Test-Path $key) 'listed in Settings > Apps'
Check ((Get-ItemProperty $key).DisplayName -eq 'Project Folder Manager') 'listed as "Project Folder Manager"'
Check ((Get-Item $exe).VersionInfo.ProductName -eq 'Project Folder Manager') 'the exe says it is Project Folder Manager'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Programs')) 'Project Folder Manager\Project Folder Manager.lnk')) 'Start menu shortcut'
Check (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Project Folder Manager.lnk')) 'desktop shortcut'

# 2. the self-check: real jobs on a real Windows
$work = Join-Path $env:RUNNER_TEMP 'pfm-self-check'
$report = Join-Path $Shots 'self-check.json'
$p = Start-Process -FilePath $exe -ArgumentList '--self-check', "`"$work`"", "`"$report`"" -PassThru -Wait
Check (Test-Path $report) 'the self-check wrote its report'
$r = Get-Content $report -Raw | ConvertFrom-Json
foreach ($s in $r.steps) { Check $s.ok "self-check: $($s.step)$(if (-not $s.ok) { " - $($s.error)" })" }
Check ($p.ExitCode -eq 0) 'the self-check passed'

# 3. open it on a sample project
$project = Join-Path $env:RUNNER_TEMP 'Sample Project'
foreach ($m in '00_Admin\Contracts', '10_Survey\01_Control Points', '10_Survey\02_Topographic Survey', '20_Piping\Isometrics', '30_Electrical', '50_Civil Works\Roads', '99_Archive') {
  New-Item -ItemType Directory -Force (Join-Path $project $m) | Out-Null
}
Set-Content (Join-Path $project '10_Survey\Survey_Report_Rev2.pdf') ('x' * 2000)
New-Item -ItemType Directory -Force $settings | Out-Null
$json = @{ v6Checked = $true; current = 0; projects = @(@{ root = $project; title = 'Windows Check'; modules = @() }); options = @{ drv = $true } } | ConvertTo-Json -Depth 5
Set-Content (Join-Path $settings 'settings.json') $json -Encoding utf8
$p = Start-Process -FilePath $exe -PassThru
Check (WaitFor { $p.Refresh(); $p.MainWindowHandle -ne 0 -and $p.MainWindowTitle -eq 'Project Folder Manager' } 30) 'opens a window titled "Project Folder Manager"'
Start-Sleep -Seconds 10 # first frame, the project, the index in the background
Check (-not $p.HasExited) 'still running after 10 seconds'
Check ((Shot 'dashboard') -gt 20) 'the screen shows the drawn dashboard, not a blank window'
Check (WaitFor { Test-Path (Join-Path $data 'index') } 30) 'the project indexed itself in the background'
$saved = Get-Content (Join-Path $settings 'settings.json') -Raw | ConvertFrom-Json
Check ($saved.projects[0].modules.Count -eq 6) 'the six folders became the module list'

# 4. a second start brings the first window forward instead of opening another copy
Start-Process -FilePath $exe
Start-Sleep -Seconds 5
Check (@(Get-Process ProjectFolderManager -ErrorAction SilentlyContinue).Count -eq 1) 'only one copy runs'

# 5. uninstall
Start-Process -FilePath (Join-Path $dir 'Uninstall.exe') -ArgumentList '/S' -Wait
Check (WaitFor { -not (Test-Path $dir) } 30) 'uninstall removes the program'
Check (WaitFor { -not (Test-Path $key) } 15) 'uninstall removes it from Settings > Apps'
Check (-not (Get-Process ProjectFolderManager -ErrorAction SilentlyContinue)) 'uninstall closes the program'
Check (-not (Test-Path $settings)) 'uninstall removes the settings'
Check (-not (Test-Path $data)) 'uninstall removes the index'
Check (-not (Test-Path (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Project Folder Manager.lnk'))) 'uninstall removes the desktop shortcut'
Write-Host 'Windows install, self-check, open and uninstall: all good'
