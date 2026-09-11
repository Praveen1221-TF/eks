resource "aws_iam_role" "bastion_terraform_admin" {
  name = "BastionTerraformAdmin"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    local.common_tags,
    {
      Name = "BastionTerraformAdmin"
    }
  )
}