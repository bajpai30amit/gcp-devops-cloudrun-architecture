param(
    [string]$ProjectId = "watchful-idea-505906-u3",
    [string]$SecretName = "mongodb-uri",
    [string]$Bucket = "gs://watchful-idea-505906-u3-devops-poc-backup",
    [string]$MongoDump = "C:\Users\amit-pro\Downloads\mongodb-database-tools-windows-x86_64-100.18.0\mongodb-database-tools-windows-x86_64-100.18.0\bin\mongodump.exe"
)

$ErrorActionPreference = "Stop"

Write-Host "============================================"
Write-Host " MongoDB Atlas Backup"
Write-Host "============================================"

# --------------------------------------------------
# 1. Validate mongodump
# --------------------------------------------------

if (-not (Test-Path $MongoDump)) {
    throw "mongodump.exe not found: $MongoDump"
}

Write-Host "[1/6] mongodump found."

# --------------------------------------------------
# 2. Retrieve MongoDB URI from Secret Manager
# --------------------------------------------------

Write-Host "[2/6] Retrieving MongoDB URI from Secret Manager..."

$MongoUri = gcloud.cmd secrets versions access latest `
    --secret=$SecretName `
    --project=$ProjectId

if ($LASTEXITCODE -ne 0) {
    throw "Unable to retrieve MongoDB URI from Secret Manager."
}

if ([string]::IsNullOrWhiteSpace($MongoUri)) {
    throw "MongoDB URI returned from Secret Manager is empty."
}

if (-not $MongoUri.StartsWith("mongodb+srv://")) {
    throw "MongoDB URI has an unexpected format."
}

# --------------------------------------------------
# 3. Create backup directory and filename
# --------------------------------------------------

Write-Host "[3/6] Preparing local backup..."

$BackupDirectory = Join-Path $PSScriptRoot "..\backups"

New-Item `
    -ItemType Directory `
    -Path $BackupDirectory `
    -Force | Out-Null

$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

$BackupName = "mongodb-backup-$Timestamp.archive.gz"

$BackupFile = Join-Path `
    $BackupDirectory `
    $BackupName

# --------------------------------------------------
# 4. Create compressed MongoDB backup
# --------------------------------------------------

Write-Host "[4/6] Creating MongoDB backup..."

& $MongoDump `
    --uri="$MongoUri" `
    --archive="$BackupFile" `
    --gzip

if ($LASTEXITCODE -ne 0) {
    throw "mongodump failed."
}

if (-not (Test-Path $BackupFile)) {
    throw "Backup file was not created."
}

$BackupInfo = Get-Item $BackupFile

if ($BackupInfo.Length -eq 0) {
    throw "Backup file is empty."
}

Write-Host "Backup created successfully."
Write-Host "File: $($BackupInfo.Name)"
Write-Host "Size: $($BackupInfo.Length) bytes"

# --------------------------------------------------
# 5. Upload backup to Google Cloud Storage
# --------------------------------------------------

Write-Host "[5/6] Uploading backup to GCS..."

$Destination = "$Bucket/mongodb/$BackupName"

gcloud.cmd storage cp `
    "$BackupFile" `
    "$Destination"

if ($LASTEXITCODE -ne 0) {
    throw "GCS upload failed."
}

# Verify object exists

gcloud.cmd storage objects describe `
    "$Destination" `
    --project=$ProjectId `
    --format="value(name,size)" | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Unable to verify uploaded GCS object."
}

Write-Host "GCS object verified."

# --------------------------------------------------
# 6. Cleanup
# --------------------------------------------------

Write-Host "[6/6] Cleaning local temporary backup..."

Remove-Item `
    $BackupFile `
    -Force

$MongoUri = $null

Write-Host ""
Write-Host "============================================"
Write-Host " BACKUP COMPLETED SUCCESSFULLY"
Write-Host "============================================"
Write-Host "Object: $Destination"
Write-Host "Timestamp: $Timestamp"