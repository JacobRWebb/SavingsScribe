# Quick Start Guide - Single Environment Setup

This guide is for setting up GitHub Actions to deploy your AWS CDK infrastructure to a single environment using the `master` branch.

## What You Need

1. **AWS Account** with admin access
2. **GitHub Repository** with admin access
3. Your GitHub repository organization/username

## Setup Steps

### 1. Create AWS OIDC Provider (One-time)

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### 2. Create IAM Role

**Get your AWS Account ID:**
```bash
aws sts get-caller-identity --query Account --output text
```

**Create the role via AWS Console:**
1. Go to IAM → Roles → Create role
2. Select "Web identity"
3. Identity provider: `token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. GitHub organization: `YOUR_ORG`
6. GitHub repository: `SavingsScribe`
7. GitHub branch: `master`
8. Role name: `github-cdk-deploy`
9. Attach policies:
   - `AWSCloudFormationFullAccess`
   - `AmazonS3FullAccess`
   - `IAMFullAccess`

**Or create via CLI:**
```bash
# Save this as trust-policy.json
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

# Create the role
aws iam create-role \
  --role-name github-cdk-deploy \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name github-cdk-deploy \
  --policy-arn arn:aws:iam::aws:policy/AWSCloudFormationFullAccess

aws iam attach-role-policy \
  --role-name github-cdk-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

aws iam attach-role-policy \
  --role-name github-cdk-deploy \
  --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
```

### 3. Add GitHub Secret

1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `AWS_ROLE_ARN`
5. Value: `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-cdk-deploy`
6. Click **Add secret**

### 4. Create GitHub Environment

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name: `production`
4. Click **Configure environment**
5. (Optional) Add protection rules:
   - ✅ Required reviewers
   - ✅ Wait timer (e.g., 5 minutes)
6. Click **Save protection rules**

### 5. Bootstrap AWS Environment

1. Push your code to GitHub (master branch)
2. Go to **Actions** tab
3. Select **Bootstrap AWS Environment** workflow
4. Click **Run workflow**
5. Click **Run workflow** button
6. Wait for completion (green checkmark)

### 6. Deploy!

**Automatic deployment:**
- Push to `master` branch → automatically deploys

**Manual deployment:**
1. Go to **Actions** tab
2. Select **CDK Deploy** workflow
3. Click **Run workflow**
4. Click **Run workflow** button

## Troubleshooting

### "Access Denied" Error
- Verify the IAM role ARN in GitHub secrets matches exactly
- Check the trust policy includes your repository name
- Ensure policies are attached to the role

### "Bootstrap Required" Error
- Run the Bootstrap workflow first (Step 5)
- Verify you have permissions in AWS

### "Environment not found" Error
- Create the `production` environment in GitHub (Step 4)

## What Happens When You Push

1. **Validate** - Builds and validates your code
2. **Synth** - Generates CloudFormation templates
3. **Deploy** - Deploys to AWS using CDK

Pull requests only run validation (no deployment).

## Security Notes

✅ **Good:**
- Uses temporary credentials via OIDC
- No static AWS keys stored in GitHub
- Role limited to specific repository and branch

❌ **Avoid:**
- Never commit AWS credentials to code
- Don't use root account credentials
- Don't give excessive permissions

## Next Steps

- Monitor deployments in CloudWatch
- Set up CloudWatch alarms for failures
- Add unit tests to validation stage
- Review CloudFormation stacks in AWS Console
