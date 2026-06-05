param(
  [string]$DeviceId = "",
  [int]$ApiPort = 3100,
  [string]$ApiPath = "/api/v1"
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
  Write-Host "[xiaotai] $Message"
}

function Require-Command([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($null -eq $command) {
    throw "Missing required command: $Name"
  }
}

Require-Command adb
Require-Command flutter

$adbArgs = @()
if ($DeviceId.Trim().Length -gt 0) {
  $adbArgs += @("-s", $DeviceId.Trim())
}

Write-Step "checking Android device"
$devices = adb devices | Select-String -Pattern "`tdevice$"
if ($devices.Count -eq 0) {
  throw "No USB debugging device found. Please confirm USB debugging is enabled and authorized."
}

Write-Step "forwarding phone 127.0.0.1:$ApiPort to computer localhost:$ApiPort"
& adb @adbArgs reverse "tcp:$ApiPort" "tcp:$ApiPort"

$baseUrl = "http://127.0.0.1:$ApiPort$ApiPath"
Write-Step "starting Flutter with XIAOTAI_API_BASE_URL=$baseUrl"
$flutterArgs = @(
  "--dart-define",
  "XIAOTAI_API_BASE_URL=$baseUrl"
)
& flutter run @flutterArgs
