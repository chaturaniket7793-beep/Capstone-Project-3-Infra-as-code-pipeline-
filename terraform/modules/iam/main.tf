# -------------------------
# ECS Task Execution Role
# -------------------------

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task-execution-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# -------------------------
# GitHub Actions OIDC Role
# -------------------------

resource "aws_iam_role" "github_actions" {
  name = "GitHubActions-ECS-ZeroTouch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::501479502035:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:chaturaniket7793-beep@285134284/Capstone-Project-3-Infra-as-code-pipeline-@1407084997:ref:refs/heads/feature/github-actions",
              "repo:chaturaniket7793-beep@285134284/Capstone-Project-3-Infra-as-code-pipeline-@1407084997:ref:refs/heads/staging",
              "repo:chaturaniket7793-beep@285134284/Capstone-Project-3-Infra-as-code-pipeline-@1407084997:ref:refs/heads/main",
              "repo:chaturaniket7793-beep@285134284/Capstone-Project-3-Infra-as-code-pipeline-@1407084997:pull_request"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHubActions-ECS-ZeroTouch"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_policy" "github_actions_ecr" {
  name        = "GitHubActions-ECR-Access"
  description = "Allows GitHub Actions to authenticate to ECR and push the app image"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRLogin"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
        Resource = "arn:aws:ecr:ap-south-1:501479502035:repository/ecs-zero-touch-dev"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

# -------------------------
# ECS Task Execution Policy
# -------------------------

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
resource "aws_iam_role_policy" "github_actions_ecs" {
  name = "GitHubActions-ECS-Deploy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = aws_iam_role.ecs_task_execution.arn
      }
    ]
  })
}