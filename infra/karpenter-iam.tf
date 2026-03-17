# ---------------------------------------------------------------
# Import existing roles into Terraform state (safe to keep - ignored if not present)
# ---------------------------------------------------------------
import {
  to = aws_iam_role.karpenter_node
  id = "KarpenterNodeRole"
}

import {
  to = aws_iam_instance_profile.karpenter_node
  id = "KarpenterNodeRole"
}

import {
  to = aws_iam_role.karpenter_controller
  id = "KarpenterControllerRole-eks-srini"
}

import {
  to = aws_iam_policy.karpenter_controller
  id = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/KarpenterControllerPolicy-eks-srini"
}

import {
  to = aws_iam_role_policy_attachment.karpenter_controller
  id = "KarpenterControllerRole-eks-srini/arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/KarpenterControllerPolicy-eks-srini"
}

import {
  to = aws_iam_role_policy_attachment.karpenter_node_worker
  id = "KarpenterNodeRole/arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

import {
  to = aws_iam_role_policy_attachment.karpenter_node_ecr
  id = "KarpenterNodeRole/arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

import {
  to = aws_iam_role_policy_attachment.karpenter_node_cni
  id = "KarpenterNodeRole/arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

import {
  to = aws_iam_role_policy_attachment.karpenter_node_ssm
  id = "KarpenterNodeRole/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------------------------------------------------------------
# Data sources
# ---------------------------------------------------------------
data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = var.eks_cluster_name
}

# Extract the bare OIDC issuer hostname (strip https://)
locals {
  oidc_issuer = trimprefix(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://")
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# ---------------------------------------------------------------
# Karpenter Node Role  (assumed by EC2 instances launched by Karpenter)
# ---------------------------------------------------------------
resource "aws_iam_role" "karpenter_node" {
  name        = "KarpenterNodeRole"
  description = "IAM role for EC2 nodes launched by Karpenter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name      = "KarpenterNodeRole"
    ManagedBy = "Terraform"
    Cluster   = var.eks_cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2NodeClass references the role name as an instance profile
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "KarpenterNodeRole"
  role = aws_iam_role.karpenter_node.name

  tags = {
    Name      = "KarpenterNodeRole"
    ManagedBy = "Terraform"
    Cluster   = var.eks_cluster_name
  }
}

# ---------------------------------------------------------------
# Karpenter Controller Role  (IRSA - assumed by karpenter pod SA)
# ---------------------------------------------------------------
resource "aws_iam_role" "karpenter_controller" {
  name        = "KarpenterControllerRole-${var.eks_cluster_name}"
  description = "IRSA role for the Karpenter controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:karpenter:karpenter"
          }
        }
      }
    ]
  })

  tags = {
    Name      = "KarpenterControllerRole-${var.eks_cluster_name}"
    ManagedBy = "Terraform"
    Cluster   = var.eks_cluster_name
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name        = "KarpenterControllerPolicy-${var.eks_cluster_name}"
  description = "Policy for Karpenter controller to manage EC2 nodes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEC2Actions"
        Effect = "Allow"
        Action = [
          "ec2:CreateFleet",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateTags",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSpotPriceHistory",
          "ec2:DescribeSubnets",
          "ec2:RunInstances",
          "ec2:TerminateInstances"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowPricingActions"
        Effect   = "Allow"
        Action   = "pricing:GetProducts"
        Resource = "*"
      },
      {
        Sid      = "AllowSSMActions"
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = "arn:aws:ssm:*:*:parameter/aws/service/*"
      },
      {
        Sid    = "AllowSQSActions"
        Effect = "Allow"
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ReceiveMessage"
        ]
        Resource = "arn:aws:sqs:*:${data.aws_caller_identity.current.account_id}:${var.eks_cluster_name}"
      },
      {
        Sid      = "AllowPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid    = "AllowIAMInstanceProfile"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowEKSDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:*:${data.aws_caller_identity.current.account_id}:cluster/${var.eks_cluster_name}"
      }
    ]
  })

  tags = {
    Name      = "KarpenterControllerPolicy-${var.eks_cluster_name}"
    ManagedBy = "Terraform"
    Cluster   = var.eks_cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}
