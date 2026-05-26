# Quick commit + push for this repo.
# Usage:
#   .\push.ps1                       # auto-message with timestamp
#   .\push.ps1 "your message here"   # custom message

param([string]$Message)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

# Bail if nothing to commit.
$status = git status --porcelain
if (-not $status) {
  Write-Host "Nothing to commit. Working tree clean." -ForegroundColor Yellow
  exit 0
}

Write-Host "Pending changes:" -ForegroundColor Cyan
Write-Host $status

if (-not $Message) {
  $Message = "Update {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm")
}

git add -A
git commit -m $Message
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

git push origin main
