# Trust policy — only EC2 can assume this role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Inline policy — scoped to ONLY the bucket this stack creates
data "aws_iam_policy_document" "s3_access" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"

    actions = ["s3:ListBucket"]

    resources = [aws_s3_bucket.app_data.arn]
  }

  statement {
    sid    = "ObjectRW"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]

    resources = ["${aws_s3_bucket.app_data.arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "s3-access"
  role   = aws_iam_role.app_role.id
  policy = data.aws_iam_policy_document.s3_access.json
}

# CloudWatch agent — for metrics & logs from the instance
resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# SSM Session Manager — replaces SSH access
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.app_role.name
}
