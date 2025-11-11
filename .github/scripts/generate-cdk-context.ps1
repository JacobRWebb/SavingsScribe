#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates CDK context parameters for Lambda deployments
.DESCRIPTION
    Reads Lambda metadata files and generates CDK context parameters
    to pass S3 keys and versions to the CDK deployment.
.PARAMETER MetadataDir
    Directory containing Lambda metadata JSON files
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$MetadataDir
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================="
Write-Host "Generating CDK Context Parameters"
Write-Host "=========================================="
Write-Host "Metadata Directory: $MetadataDir"

# Find all metadata files
$metadataFiles = Get-ChildItem -Path $MetadataDir -Filter "*-metadata.json"

if ($metadataFiles.Count -eq 0) {
    Write-Host "No metadata files found. No Lambda deployments to process."
    if ($env:GITHUB_OUTPUT) {
        "cdk_context=" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    }
    exit 0
}

Write-Host "Found $($metadataFiles.Count) metadata file(s)"

# Build CDK context parameters
$contextParams = @()

foreach ($file in $metadataFiles) {
    Write-Host "`nProcessing: $($file.Name)"
    $metadata = Get-Content $file.FullName -Raw | ConvertFrom-Json
    
    Write-Host "  Lambda: $($metadata.lambda)"
    Write-Host "  Version: $($metadata.version)"
    Write-Host "  S3 Key: $($metadata.s3_key)"
    
    # Convert Lambda name to context key format
    # Example: SavingsScribe.HelloWorld.Lambda -> HelloWorldLambdaS3Key
    $lambdaBaseName = $metadata.lambda -replace '^SavingsScribe\.', '' -replace '\.Lambda$', '' -replace '\.', ''
    
    # Add S3 key context
    $s3KeyParam = "${lambdaBaseName}LambdaS3Key=$($metadata.s3_key)"
    $contextParams += "-c"
    $contextParams += $s3KeyParam
    
    Write-Host "  Context: $s3KeyParam"
    
    # Add S3 object version if available
    if ($metadata.s3_object_version) {
        $s3VersionParam = "${lambdaBaseName}LambdaS3Version=$($metadata.s3_object_version)"
        $contextParams += "-c"
        $contextParams += $s3VersionParam
        Write-Host "  Context: $s3VersionParam"
    }
}

# Join context parameters into a single string
$contextString = $contextParams -join " "

Write-Host "`n=========================================="
Write-Host "CDK Context Generated"
Write-Host "=========================================="
Write-Host "Context Parameters:"
Write-Host $contextString

# Set GitHub Actions output
if ($env:GITHUB_OUTPUT) {
    Write-Host "`nWriting to GITHUB_OUTPUT"
    "cdk_context=$contextString" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}

# Also output to a file for easy reference
$contextFile = Join-Path $MetadataDir "cdk-context.txt"
$contextString | Out-File -FilePath $contextFile -Encoding utf8
Write-Host "Context saved to: $contextFile"
