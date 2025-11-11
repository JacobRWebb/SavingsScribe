# Lambda Deployment Pipeline

## Overview

This document describes the extensible Lambda deployment pipeline that automatically detects changes, builds, versions, and deploys Lambda functions to AWS using S3 and CloudFormation.

## Architecture

### Key Components

1. **components.json** - Source of truth for all Lambda functions
2. **GitHub Actions Workflow** - Automated CI/CD pipeline
3. **PowerShell Scripts** - Change detection and deployment automation
4. **S3 Bucket** - Versioned storage for Lambda packages
5. **CDK Infrastructure** - CloudFormation deployment with S3 references

### Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Code Push to Repository                                      │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Validate Job                                                  │
│    - Build solution                                              │
│    - Detect Lambda changes (components.json)                    │
│    - Compare with previous commit                               │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Build Lambdas Job (if changes detected)                      │
│    - Create/verify S3 bucket                                    │
│    - Build each changed Lambda                                  │
│    - Generate version hash                                      │
│    - Upload to S3 (versioned + latest)                          │
│    - Generate CDK context parameters                            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. CDK Synth Job                                                 │
│    - Generate CloudFormation templates                          │
│    - Upload templates as artifacts                              │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Deploy Job                                                    │
│    - Pass S3 keys/versions via CDK context                      │
│    - Deploy CloudFormation stack                                │
│    - CloudFormation only updates if S3 version changed          │
└─────────────────────────────────────────────────────────────────┘
```

## Change Detection

### How It Works

The pipeline uses `detect-lambda-changes.ps1` to:

1. Read `components.json` to discover all Lambda functions
2. Compare each Lambda's directory against the previous commit
3. Output a JSON list of changed Lambdas
4. Skip unchanged Lambdas entirely

### Example components.json

```json
{
  "Information": {
    "DotnetVersion": "8.0"
  },
  "components": {
    "SavingsScribe.HelloWorld.Lambda": {
      "Type": "Lambda",
      "Path": "SavingsScribe.HelloWorld.Lambda/SavingsScribe.HelloWorld.Lambda",
      "Tests": {
        "SavingsScribe.HelloWorld.Lambda.Tests": {
          "Type": "UnitTests",
          "Path": "SavingsScribe.HelloWorld.Lambda/SavingsScribe.HelloWorld.Lambda.Tests"
        }
      }
    },
    "SavingsScribe.AnotherFunction.Lambda": {
      "Type": "Lambda",
      "Path": "SavingsScribe.AnotherFunction.Lambda/SavingsScribe.AnotherFunction.Lambda",
      "Tests": {}
    }
  }
}
```

## Versioning Strategy

### Version Format

```
YYYYMMDD-HHMMSS-HASH8
```

Example: `20250104-143022-a3f2b1c8`

- **Timestamp**: When the build occurred
- **Hash**: First 8 characters of SHA256 hash of the package

### S3 Structure

```
s3://savingsscribe-lambda-deployments-{ACCOUNT_ID}/
├── lambdas/
│   ├── SavingsScribe.HelloWorld.Lambda/
│   │   ├── latest.zip                           # Always points to latest
│   │   ├── 20250104-143022-a3f2b1c8.zip        # Versioned package
│   │   └── 20250103-120000-b2c3d4e5.zip        # Previous version
│   └── SavingsScribe.AnotherFunction.Lambda/
│       ├── latest.zip
│       └── 20250104-143022-c4d5e6f7.zip
```

### S3 Bucket Configuration

- **Versioning**: Enabled (provides additional version tracking)
- **Lifecycle Policy**: Non-current versions expire after 90 days
- **Retention**: Keeps deployment history while managing costs

## CloudFormation Change Detection

### How CloudFormation Detects Changes

CloudFormation automatically detects Lambda changes through:

1. **S3 Object Version**: If S3 versioning is enabled, CDK passes the version ID
2. **S3 Key Change**: Different S3 keys trigger updates
3. **Hash Comparison**: CloudFormation compares the S3 object hash

### CDK Context Parameters

The pipeline passes Lambda deployment info via CDK context:

```bash
cdk deploy \
  -c HelloWorldLambdaS3Key=lambdas/SavingsScribe.HelloWorld.Lambda/latest.zip \
  -c HelloWorldLambdaS3Version=abc123xyz \
  -c AnotherFunctionLambdaS3Key=lambdas/SavingsScribe.AnotherFunction.Lambda/latest.zip \
  -c AnotherFunctionLambdaS3Version=def456uvw \
  --all
```

### MainStack.cs Implementation

```csharp
var helloWorldLambda = new LambdaFunction(this, "HelloWorldLambda", new LambdaFunctionProps
{
    FunctionName = "SavingsScribe-HelloWorld",
    Handler = "SavingsScribe.HelloWorld.Lambda::SavingsScribe.HelloWorld.Lambda.Function::FunctionHandler",
    S3Bucket = lambdaBucket,
    S3Key = this.Node.TryGetContext("HelloWorldLambdaS3Key")?.ToString() ?? "lambdas/SavingsScribe.HelloWorld.Lambda/latest.zip",
    S3ObjectVersion = this.Node.TryGetContext("HelloWorldLambdaS3Version")?.ToString()
});
```

## Adding New Lambdas

### Step 1: Create Lambda Project

Create your Lambda function following the standard structure:

```
SavingsScribe.NewFunction.Lambda/
├── SavingsScribe.NewFunction.Lambda/
│   ├── Function.cs
│   └── SavingsScribe.NewFunction.Lambda.csproj
└── SavingsScribe.NewFunction.Lambda.Tests/
    └── SavingsScribe.NewFunction.Lambda.Tests.csproj
```

### Step 2: Update components.json

Add your Lambda to `components.json`:

```json
{
  "components": {
    "SavingsScribe.NewFunction.Lambda": {
      "Type": "Lambda",
      "Path": "SavingsScribe.NewFunction.Lambda/SavingsScribe.NewFunction.Lambda",
      "Tests": {
        "SavingsScribe.NewFunction.Lambda.Tests": {
          "Type": "UnitTests",
          "Path": "SavingsScribe.NewFunction.Lambda/SavingsScribe.NewFunction.Lambda.Tests"
        }
      }
    }
  }
}
```

### Step 3: Update MainStack.cs

Add the Lambda to your CDK stack:

```csharp
// In MainStack constructor
var newFunctionLambda = new LambdaFunction(this, "NewFunctionLambda", new LambdaFunctionProps
{
    FunctionName = "SavingsScribe-NewFunction",
    Description = "Description of new function",
    Handler = "SavingsScribe.NewFunction.Lambda::SavingsScribe.NewFunction.Lambda.Function::FunctionHandler",
    S3Bucket = lambdaBucket,
    S3Key = this.Node.TryGetContext("NewFunctionLambdaS3Key")?.ToString() ?? "lambdas/SavingsScribe.NewFunction.Lambda/latest.zip",
    S3ObjectVersion = this.Node.TryGetContext("NewFunctionLambdaS3Version")?.ToString()
});
```

### Step 4: Commit and Push

The pipeline will automatically:
1. Detect the new Lambda
2. Build and upload it to S3
3. Deploy it via CloudFormation

## Scripts Reference

### detect-lambda-changes.ps1

**Purpose**: Detects which Lambdas have changed since the last commit

**Parameters**:
- `ComponentsFile`: Path to components.json
- `BaseRef`: Git reference to compare against (default: HEAD~1)

**Outputs**:
- `changed`: Boolean indicating if any Lambdas changed
- `count`: Number of changed Lambdas
- `lambdas`: JSON array of changed Lambda objects

### build-and-upload-lambda.ps1

**Purpose**: Builds, packages, and uploads a Lambda to S3

**Parameters**:
- `LambdaName`: Name of the Lambda function
- `LambdaPath`: Path to the Lambda project
- `S3Bucket`: S3 bucket for deployment
- `DotnetVersion`: .NET version (default: 8.0)

**Outputs**:
- `lambda_name`: Name of the Lambda
- `version`: Generated version string
- `s3_key`: S3 key for latest package
- `s3_versioned_key`: S3 key for versioned package
- `s3_object_version`: S3 object version ID (if versioning enabled)
- `hash`: SHA256 hash of the package

### generate-cdk-context.ps1

**Purpose**: Generates CDK context parameters from Lambda metadata

**Parameters**:
- `MetadataDir`: Directory containing Lambda metadata JSON files

**Outputs**:
- `cdk_context`: String of CDK context parameters

## Workflow Jobs

### 1. validate

**Purpose**: Validate code and detect changes

**Outputs**:
- `should-deploy`: Whether to proceed with deployment
- `lambdas-changed`: Whether any Lambdas changed
- `lambdas-json`: JSON array of changed Lambdas

### 2. build-lambdas

**Purpose**: Build and upload changed Lambdas

**Runs When**: Lambdas have changed and should deploy

**Outputs**:
- `cdk-context`: CDK context parameters for deployment

**Artifacts**:
- `lambda-metadata`: JSON metadata files for each Lambda

### 3. synth

**Purpose**: Generate CloudFormation templates

**Runs When**: Validation passed (regardless of Lambda changes)

**Artifacts**:
- `cdk-templates`: CloudFormation templates from CDK synth

### 4. deploy

**Purpose**: Deploy infrastructure to AWS

**Runs When**: Synth succeeded

**Uses**:
- CDK context from build-lambdas job
- CloudFormation templates from synth job

## Benefits

### 1. Extensibility

- Add new Lambdas by updating `components.json` only
- No workflow changes needed
- Automatic discovery and processing

### 2. Efficiency

- Only builds and uploads changed Lambdas
- CloudFormation only updates changed resources
- Reduces deployment time and costs

### 3. Versioning

- Full version history in S3
- Rollback capability
- Audit trail of all deployments

### 4. Separation of Concerns

- **components.json**: What exists
- **Infrastructure code**: How it's configured
- **Workflow**: How it's deployed
- **Scripts**: Reusable automation logic

### 5. Clean Architecture Compliance

- **Single Responsibility**: Each script has one purpose
- **Open/Closed**: Add Lambdas without modifying workflow
- **Dependency Inversion**: Infrastructure depends on abstractions (S3 keys)
- **DRY**: Reusable scripts for all Lambdas

## Troubleshooting

### Lambda Not Detected as Changed

**Issue**: Lambda changed but not detected

**Solutions**:
1. Verify the `Path` in `components.json` is correct
2. Check that changes are committed
3. Ensure `fetch-depth: 0` in checkout action

### S3 Upload Fails

**Issue**: Cannot upload to S3 bucket

**Solutions**:
1. Verify AWS credentials are configured
2. Check IAM role has S3 permissions
3. Ensure bucket name follows AWS naming rules

### CloudFormation Not Updating Lambda

**Issue**: Lambda code changed but CloudFormation shows no changes

**Solutions**:
1. Verify S3 object version is being passed
2. Check CDK context parameters are correct
3. Ensure S3 bucket versioning is enabled

### Build Fails

**Issue**: Lambda build or publish fails

**Solutions**:
1. Verify .NET version matches `components.json`
2. Check Lambda project builds locally
3. Review build logs for specific errors

## Security Considerations

1. **IAM Roles**: Use OIDC with minimal permissions
2. **S3 Bucket**: Enable encryption at rest
3. **Versioning**: Provides audit trail and rollback
4. **Secrets**: Never commit AWS credentials
5. **Least Privilege**: Lambda execution roles should be minimal

## Future Enhancements

1. **Parallel Builds**: Build multiple Lambdas concurrently
2. **Integration Tests**: Run tests before deployment
3. **Blue/Green Deployments**: Use Lambda aliases and versions
4. **Rollback Automation**: Automatic rollback on errors
5. **Cost Tracking**: Tag resources with deployment metadata
6. **Notifications**: Slack/email notifications for deployments
