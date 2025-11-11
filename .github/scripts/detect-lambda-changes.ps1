#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Detects changes in Lambda functions based on components.json
.DESCRIPTION
    Reads components.json to discover all Lambda functions and checks if they have changed
    since the last commit. Outputs a JSON array of changed Lambdas.
.PARAMETER ComponentsFile
    Path to components.json file
.PARAMETER BaseRef
    Base git reference to compare against (default: HEAD~1)
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ComponentsFile,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseRef = "HEAD~1"
)

$ErrorActionPreference = "Stop"

# Read components.json
Write-Host "Reading components configuration from: $ComponentsFile"
$componentsJson = Get-Content $ComponentsFile -Raw | ConvertFrom-Json

# Extract Lambda components
$lambdas = @()
foreach ($componentName in $componentsJson.components.PSObject.Properties.Name) {
    $component = $componentsJson.components.$componentName
    if ($component.Type -eq "Lambda") {
        $lambdas += [PSCustomObject]@{
            Name = $componentName
            Path = $component.Path
            Tests = $component.Tests
        }
    }
}

Write-Host "Found $($lambdas.Count) Lambda function(s) in components.json"

# Detect changes for each Lambda
$changedLambdas = @()

foreach ($lambda in $lambdas) {
    Write-Host "`nChecking changes for: $($lambda.Name)"
    Write-Host "  Path: $($lambda.Path)"
    
    # Check if this is the first commit or if BaseRef exists
    $isFirstCommit = $false
    try {
        git rev-parse --verify $BaseRef 2>&1 | Out-Null
    } catch {
        $isFirstCommit = $true
        Write-Host "  First commit detected - marking as changed"
    }
    
    if ($isFirstCommit) {
        $changedLambdas += $lambda
        continue
    }
    
    # Get changed files in the Lambda directory
    $changedFiles = git diff --name-only $BaseRef HEAD -- "$($lambda.Path)/*"
    
    if ($changedFiles) {
        Write-Host "  Changes detected:"
        $changedFiles | ForEach-Object { Write-Host "    - $_" }
        $changedLambdas += $lambda
    } else {
        Write-Host "  No changes detected"
    }
}

# Output results
Write-Host "`n=========================================="
Write-Host "Summary: $($changedLambdas.Count) Lambda(s) changed"
Write-Host "=========================================="

if ($changedLambdas.Count -gt 0) {
    Write-Host "Changed Lambdas:"
    $changedLambdas | ForEach-Object { Write-Host "  - $($_.Name)" }
}

# Output as JSON for GitHub Actions
$output = @{
    changed = ($changedLambdas.Count -gt 0)
    count = $changedLambdas.Count
    lambdas = $changedLambdas
}

$outputJson = $output | ConvertTo-Json -Compress -Depth 10
Write-Host "`nJSON Output:"
Write-Host $outputJson

# Set GitHub Actions output if running in CI
if ($env:GITHUB_OUTPUT) {
    Write-Host "`nWriting to GITHUB_OUTPUT: $env:GITHUB_OUTPUT"
    "changed=$($output.changed.ToString().ToLower())" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "count=$($output.count)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
    "lambdas=$outputJson" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding utf8
}
