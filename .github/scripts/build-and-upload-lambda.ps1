#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds and uploads a Lambda function to S3 with versioning
.DESCRIPTION
    Publishes a .NET Lambda function, packages it as a zip, and uploads to S3 with a version tag.
    Generates a hash of the package to track changes.
.PARAMETER LambdaName
    Name of the Lambda function (from components.json)
.PARAMETER LambdaPath
    Path to the Lambda project directory
.PARAMETER S3Bucket
    S3 bucket name for Lambda deployments
.PARAMETER DotnetVersion
    .NET version to use (default: 8.0)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$LambdaName,
    
    [Parameter(Mandatory=$true)]
    [string]$LambdaPath,
    
    [Parameter(Mandatory=$true)]
    [string]$S3Bucket,
    
    [Parameter(Mandatory=$false)]
    [string]$DotnetVersion = "8.0"
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "Building Lambda: $LambdaName"
Write-Host "=========================================="
Write-Host "Path: $LambdaPath"
Write-Host "S3 Bucket: $S3Bucket"
Write-Host "Dotnet Version: $DotnetVersion"

# Create output directory
$outputDir = "lambda-packages"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

# Publish the Lambda
Write-Host "`nPublishing Lambda..."
$publishDir = Join-Path $outputDir "$LambdaName-publish"
dotnet publish $LambdaPath `
    --configuration Release `
    --runtime linux-x64 `
    --self-contained false `
    --output $publishDir `
    /p:GenerateRuntimeConfigurationFiles=true `
    /p:PublishReadyToRun=true

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to publish Lambda: $LambdaName"
    exit 1
}

# Create zip package
Write-Host "`nCreating deployment package..."
$zipFile = Join-Path $outputDir "$LambdaName.zip"
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

# Use PowerShell's Compress-Archive
Compress-Archive -Path "$publishDir\*" -DestinationPath $zipFile -CompressionLevel Optimal

Write-Host "Package created: $zipFile"
$zipSize = (Get-Item $zipFile).Length / 1MB
Write-Host "Package size: $([math]::Round($zipSize, 2)) MB"

# Calculate hash for versioning
Write-Host "`nCalculating package hash..."
$hash = (Get-FileHash -Path $zipFile -Algorithm SHA256).Hash
$shortHash = $hash.Substring(0, 8)
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$version = "$timestamp-$shortHash"

Write-Host "Version: $version"
Write-Host "Hash: $hash"

# Upload to S3
Write-Host "`nUploading to S3..."
$s3Key = "lambdas/$LambdaName/$version.zip"
$s3LatestKey = "lambdas/$LambdaName/latest.zip"

# Upload versioned package
Write-Host "Uploading versioned package: s3://$S3Bucket/$s3Key"
aws s3 cp $zipFile "s3://$S3Bucket/$s3Key" --metadata "hash=$hash,lambda=$LambdaName,version=$version"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to upload versioned package to S3"
    exit 1
}

# Upload as latest
Write-Host "Uploading as latest: s3://$S3Bucket/$s3LatestKey"
aws s3 cp $zipFile "s3://$S3Bucket/$s3LatestKey" --metadata "hash=$hash,lambda=$LambdaName,version=$version"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to upload latest package to S3"
    exit 1
}

# Get S3 object version (if versioning is enabled)
Write-Host "`nRetrieving S3 object version..."
$s3VersionOutput = aws s3api head-object --bucket $S3Bucket --key $s3LatestKey --query 'VersionId' --output text

if ($LASTEXITCODE -eq 0 -and $s3VersionOutput -ne "null") {
    $s3ObjectVersion = $s3VersionOutput
    Write-Host "S3 Object Version: $s3ObjectVersion"
} else {
    $s3ObjectVersion = ""
    Write-Host "S3 versioning not enabled or version not available"
}

# Output results
Write-Host "`n=========================================="
Write-Host "Upload Complete"
Write-Host "=========================================="
Write-Host "Lambda: $LambdaName"
Write-Host "Version: $version"
Write-Host "S3 Key: $s3Key"
Write-Host "S3 Latest Key: $s3LatestKey"
if ($s3ObjectVersion) {
    Write-Host "S3 Object Version: $s3ObjectVersion"
}
Write-Host "Hash: $hash"

# Set GitHub Actions outputs
if ($env:GITHUB_OUTPUT) {
    Write-Host "`nWriting to GITHUB_OUTPUT"
    "lambda_name=$LambdaName" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "version=$version" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "s3_key=$s3LatestKey" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "s3_versioned_key=$s3Key" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "hash=$hash" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    
    if ($s3ObjectVersion) {
        "s3_object_version=$s3ObjectVersion" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
}

# Create deployment metadata file
$metadata = @{
    lambda = $LambdaName
    version = $version
    hash = $hash
    s3_key = $s3LatestKey
    s3_versioned_key = $s3Key
    s3_object_version = $s3ObjectVersion
    timestamp = $timestamp
    size_mb = [math]::Round($zipSize, 2)
}

$metadataFile = Join-Path $outputDir "$LambdaName-metadata.json"
$metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataFile -Encoding utf8
Write-Host "`nMetadata saved to: $metadataFile"
