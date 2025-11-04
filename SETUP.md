# AWS CDK GitHub Actions Setup Guide

This guide will walk you through setting up GitHub Actions workflows for deploying your AWS CDK infrastructure to AWS.

## Prerequisites

- AWS CLI installed and configured
- GitHub repository with admin access
- AWS account with appropriate permissions
- .NET 8.0 SDK

## Quick Setup (Recommended)

### Step 1: Create AWS OIDC Provider

Run this command once in your AWS account:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### Step 2: Create IAM Role

Create an IAM role named `github-cdk-deploy` with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/SavingsScribe:ref:refs/heads/master"
        }
      }
    }
  ]
}
```

Attach these policies:
- `AWSCloudFormationFullAccess`
- `AmazonS3FullAccess`
- `IAMFullAccess`

### Step 3: Configure GitHub Secret

Add this secret to your GitHub repository (`Settings > Secrets and variables > Actions`):

```
AWS_ROLE_ARN: arn:aws:iam::YOUR_ACCOUNT_ID:role/github-cdk-deploy
```

### Step 4: Configure GitHub Environment

1. Go to `Settings > Environments` in your GitHub repository
2. Create environment: `production`
3. Configure protection rules (optional):
   - Require reviewers
   - Wait timer

### Step 5: Bootstrap Environment

1. Go to the Actions tab in GitHub
2. Select "Bootstrap AWS Environment" workflow
3. Click "Run workflow"

### Step 6: Test Deployment

1. Push changes to `master` branch → triggers deployment
2. Or use manual dispatch from Actions tab

## Manual Setup (Advanced)

If you prefer to set up everything manually:

### 1. Create OIDC Provider

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Roles

Create three IAM roles with the following trust policy:

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
          "token.actions.githubusercontent.com:sub": "repo:YOUR_ORG/SavingsScribe:ref:refs/heads/master"
        }
      }
    }
  ]
}
```

Attach these policies to the role:
- `AWSCloudFormationFullAccess`
- `AmazonS3FullAccess`
- `IAMFullAccess`

### 3. Configure GitHub

Follow steps 2-5 from the Quick Setup section.

## Security Best Practices

### ✅ Recommended
- Use OIDC authentication (no static credentials)
- Implement environment protection rules
- Use least privilege IAM roles
- Enable audit logging
- Monitor deployment activities

### ❌ Avoid
- Hardcoding AWS credentials in workflows
- Using root account credentials
- Giving excessive permissions to IAM roles
- Skipping environment protection rules

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Verify IAM role trust relationships
- Check attached policies
- Ensure GitHub secrets are correctly configured

**"Bootstrap required" errors:**
- Run the bootstrap workflow for the affected environment
- Verify AWS account has sufficient permissions

**"CDK command not found" errors:**
- Check Node.js setup in workflow
- Verify CDK installation step

### Debugging Steps

1. Check GitHub Actions logs for detailed error messages
2. Verify AWS CloudFormation events in AWS console
3. Test IAM role permissions manually:
   ```bash
   aws sts assume-role-with-web-identity \
     --role-arn "arn:aws:iam::ACCOUNT_ID:role/github-cdk-dev" \
     --role-session-name "test-session" \
     --web-identity-token "YOUR_TOKEN"
   ```

## Workflow Features

### Automated Deployments
- **Master branch** → Production environment
- **Pull requests** → Validation only (no deployment)

### Manual Deployments
- Deploy via workflow dispatch
- Bootstrap environment as needed

### Safety Features
- Environment protection rules
- Approval requirements for production
- Comprehensive validation before deployment
- Artifact retention for templates

### Extensibility
- Easy to add new environments
- Reusable workflow components
- Configurable CDK operations
- Environment-specific parameters

## Monitoring and Observability

### AWS Monitoring
- CloudFormation stack events
- CloudTrail API logging
- CloudWatch metrics and alarms
- AWS Config compliance

### GitHub Monitoring
- Workflow execution logs
- Deployment history
- Environment protection audit trail

## Next Steps

1. **Customize for your needs**: Modify workflows to match your specific requirements
2. **Add testing**: Include unit/integration tests in the validation stage
3. **Set up monitoring**: Configure CloudWatch alerts for deployment failures
4. **Document processes**: Create runbooks for common operational tasks
5. **Add more environments**: If needed, extend workflows for dev/staging environments

## Support

For issues with:
- **GitHub Actions**: Check GitHub Actions documentation
- **AWS CDK**: Refer to AWS CDK Developer Guide
- **IAM Roles**: Consult AWS IAM documentation
- **Setup Scripts**: Review the script logs and error messages

Remember to regularly review and update your security configurations as AWS and GitHub best practices evolve.
