# GitHub Actions Workflows for AWS CDK

This directory contains GitHub Actions workflows for deploying AWS CDK infrastructure following SOLID principles and best practices.

## Architecture Overview

### SOLID Principles Implementation

1. **Single Responsibility**: Each workflow has a specific purpose
   - `cdk-deploy.yml`: Main deployment orchestration
   - `cdk-operations.yml`: Reusable CDK operations
   - `bootstrap-environments.yml`: Environment bootstrapping

2. **Open/Closed**: Workflows are extensible without modification
   - Configurable via inputs and secrets
   - Reusable workflow for different operations

3. **Interface Segregation**: Minimal, focused workflows
   - Each workflow exposes only necessary inputs
   - No unused parameters or secrets

4. **Dependency Inversion**: Abstractions over concretions
   - Uses AWS role-based authentication instead of static credentials
   - Environment-agnostic deployment logic

## Workflows

### 1. CDK Deploy (`cdk-deploy.yml`)

**Triggers:**
- Push to `master` branch
- Pull requests to `master`
- Manual dispatch

**Jobs:**
- `validate`: Code validation, build, and Lambda change detection
- `build-lambdas`: Build and upload changed Lambda functions to S3 with versioning
- `synth`: CDK synthesis to generate CloudFormation templates
- `deploy`: Deploy to AWS environment with Lambda S3 references

**Lambda Deployment:**
See [LAMBDA-DEPLOYMENT.md](./LAMBDA-DEPLOYMENT.md) for comprehensive documentation on the extensible Lambda deployment pipeline, including:
- Change detection based on `components.json`
- S3 versioning and storage
- CloudFormation change detection
- Adding new Lambda functions

### 2. CDK Operations (`cdk-operations.yml`)

**Purpose**: Reusable workflow for common CDK operations
- Deploy
- Destroy
- Diff
- Bootstrap

**Usage**: Called by other workflows for specific operations

### 3. Bootstrap Environment (`bootstrap-environments.yml`)

**Purpose**: Bootstrap AWS environment for CDK deployment
- Manual dispatch only
- One-time setup per AWS account/region

## AWS Authentication Best Practices

### Recommended Approach: IAM Roles with OIDC

1. **GitHub OIDC Provider Setup**:
   ```bash
   # In your AWS account
   aws iam create-open-id-connect-provider \
     --url https://token.actions.githubusercontent.com \
     --client-id-list sts.amazonaws.com \
     --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
   ```

2. **Create IAM Role**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
         },
         "Action": "sts:AssumeRoleWithWebIdentity",
         "Condition": {
           "StringLike": {
             "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/YOUR_REPO:ref:refs/heads/master"
           }
         }
       }
     ]
   }
   ```

3. **Attach Required Policies**:
   - `AWSCloudFormationFullAccess`
   - `AmazonS3FullAccess` (for CDK assets)
   - `IAMFullAccess` (for CDK-managed roles)

### GitHub Secrets Configuration

Required secret in GitHub repository settings:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `AWS_ROLE_ARN` | IAM role ARN for deployment | `arn:aws:iam::123456789012:role/github-cdk-deploy` |

### Alternative: AWS Credentials (Less Secure)

If you must use static credentials (not recommended for production):

| Secret Name | Description |
|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `AWS_SESSION_TOKEN` | AWS session token (if using temporary credentials) |

## Environment Protection Rules

Configure GitHub environment protection rules:

1. **Production**: 
   - Optional: Require reviewers
   - Optional: Wait timer
   - Optional: Restrict who can deploy

## Usage Examples

### Manual Deployment

1. Go to Actions tab in GitHub
2. Select "CDK Deploy" workflow
3. Click "Run workflow"
4. Click "Run workflow"

### Bootstrap Environment

1. Go to Actions tab in GitHub
2. Select "Bootstrap AWS Environment" workflow
3. Click "Run workflow"
4. Optionally specify AWS region
5. Click "Run workflow"

## Security Considerations

1. **Use OIDC authentication** instead of static credentials
2. **Implement least privilege** for IAM roles
3. **Use environment protection rules** for production
4. **Enable audit logging** for all AWS actions
5. **Rotate credentials regularly** if using static credentials
6. **Monitor deployment activities** with CloudTrail

## Extending the Workflows

### Adding New CDK Stacks

1. Update `Program.cs` to include new stacks
2. Modify workflow inputs if stack-specific configuration needed
3. Update deployment commands if stack-specific parameters required

### Custom Deployment Steps

1. Extend the reusable `cdk-operations.yml` workflow
2. Add new operation types as needed
3. Maintain consistent interface patterns

## Troubleshooting

### Common Issues

1. **Permission Denied**: Check IAM role policies and trust relationships
2. **Bootstrap Required**: Run bootstrap workflow before first deployment
3. **Region Mismatch**: Ensure AWS region consistency across workflows
4. **CDK Version Conflicts**: Update CDK version in environment variables

### Debugging Steps

1. Check workflow logs for specific error messages
2. Verify AWS CloudFormation events in AWS console
3. Validate IAM role permissions
4. Check CDK version compatibility

## Monitoring and Observability

1. **CloudFormation Events**: Monitor stack creation/update/deletion
2. **AWS CloudTrail**: Track all API calls
3. **GitHub Actions Logs**: Review workflow execution details
4. **AWS Config**: Monitor resource compliance
5. **CloudWatch Alarms**: Set up notifications for critical failures
