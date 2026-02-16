# Get current AWS account info
data "aws_caller_identity" "current" {}

# Use existing OIDC Provider for GitHub Actions
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# IAM Role for GitHub Actions
resource "aws_iam_role" "github_actions" {
  name        = "GitHubActionsRole"
  description = "Role for GitHub Actions to deploy infrastructure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # GitHub repository: sriniboosaraju/myapp-db-db
            "token.actions.githubusercontent.com:sub" = "repo:sriniboosaraju/myapp-db-db:*"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "GitHubActionsRole"
    ManagedBy = "Terraform"
    Purpose   = "GitHub Actions CI/CD"
  }
}

# Attach permissions to the role
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Outputs
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "⭐ Add this ARN as AWS_ROLE_TO_ASSUME secret in GitHub"
}

output "aws_account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}
