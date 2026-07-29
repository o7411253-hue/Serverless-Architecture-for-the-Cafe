# ==========================================
# LOCALS
# ==========================================

locals {
  # Lambda Function Names
  dataextractor_function_name = "salesAnalysisReportDataExtractor"
  report_function_name        = "salesAnalysisReport"
  
  # AWS Account ID
  aws_account_id = "123456789012"
  aws_region     = "us-east-1"
  
  # Common Tags
  common_tags = {
    Project     = "CafeSalesReport"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
  
  # RDS Configuration
  rds_endpoint = "cafe-database.0a1b2c3d4e5f.us-east-1.rds.amazonaws.com"
  rds_port     = 3306
  rds_db_name  = "cafe_db"
  rds_username = "cafe_admin"
  rds_password = "CafeDBPass123!@#"
  
  # VPC Configuration
  vpc_id             = "vpc-0a1b2c3d4e5f67890"
  private_subnet_ids = ["subnet-0a1b2c3d4e5f67890", "subnet-0b2c3d4e5f678901a"]
  database_sg_id     = "sg-0a1b2c3d4e5f67890"
  
  # Lambda Configuration
  lambda_dataextractor_filename = "salesAnalysisReportDataExtractor.zip"
  lambda_report_filename        = "salesAnalysisReport.zip"
  lambda_dataextractor_handler  = "salesAnalysisReportDataExtractor.lambda_handler"
  lambda_report_handler         = "salesAnalysisReport.lambda_handler"
  lambda_runtime                = "python3.11"
  lambda_memory_size            = 128
  lambda_timeout                = 30
  
  # SNS Configuration
  sns_topic_name     = "SalesReportTopic"
  sns_display_name   = "Sales Report Topic"
  notification_email = "frank.martha@example.com"
  
  # EventBridge Configuration
  schedule_expression = "cron(30 21 * * ? *)"  # 9:30 PM UTC
  scheduler_role_arn  = "arn:aws:iam::123456789012:role/mySchedulerRole"
  
  # Secrets Manager
  secrets_prefix = "/cafe"
}

# ==========================================
# SECURITY GROUP - LAMBDA SG
# ==========================================

resource "aws_security_group" "lambda" {
  name        = "LambdaSG"
  description = "Security group for Lambda functions to access RDS"
  vpc_id      = local.vpc_id
  
  tags = merge(local.common_tags, {
    Name = "LambdaSG"
  })
}

# Outbound Rules - Allow all traffic
resource "aws_security_group_rule" "lambda_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
  
  description = "Allow all outbound traffic"
}

# Inbound Rule from LambdaSG to DatabaseSG
resource "aws_security_group_rule" "lambda_to_database" {
  type                     = "ingress"
  from_port                = local.rds_port
  to_port                  = local.rds_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = local.database_sg_id
  
  description = "Allow MySQL/Aurora from LambdaSG"
}

# ==========================================
# SECRETS MANAGER - STORE DATABASE CREDENTIALS
# ==========================================

resource "aws_secretsmanager_secret" "db_url" {
  name = "${local.secrets_prefix}/dbUrl"
  
  tags = merge(local.common_tags, {
    Name = "Cafe-DB-URL"
  })
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = local.rds_endpoint
}

resource "aws_secretsmanager_secret" "db_name" {
  name = "${local.secrets_prefix}/dbName"
  
  tags = merge(local.common_tags, {
    Name = "Cafe-DB-Name"
  })
}

resource "aws_secretsmanager_secret_version" "db_name" {
  secret_id     = aws_secretsmanager_secret.db_name.id
  secret_string = local.rds_db_name
}

resource "aws_secretsmanager_secret" "db_user" {
  name = "${local.secrets_prefix}/dbUser"
  
  tags = merge(local.common_tags, {
    Name = "Cafe-DB-User"
  })
}

resource "aws_secretsmanager_secret_version" "db_user" {
  secret_id     = aws_secretsmanager_secret.db_user.id
  secret_string = local.rds_username
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "${local.secrets_prefix}/dbPassword"
  
  tags = merge(local.common_tags, {
    Name = "Cafe-DB-Password"
  })
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = local.rds_password
}

# ==========================================
# IAM ROLES AND POLICIES
# ==========================================

# --- DATA EXTRACTOR IAM ROLE ---
resource "aws_iam_role" "dataextractor" {
  name = "salesAnalysisReportDERole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "salesAnalysisReportDERole"
  })
}

# Data Extractor Policy
resource "aws_iam_policy" "dataextractor" {
  name        = "salesAnalysisReportDEPolicy"
  description = "Policy for DataExtractor Lambda to read secrets and manage ENIs"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:*"
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_url.arn,
          aws_secretsmanager_secret.db_name.arn,
          aws_secretsmanager_secret.db_user.arn,
          aws_secretsmanager_secret.db_password.arn
        ]
      },
      {
        Sid    = "EC2NetworkInterfaces"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dataextractor" {
  role       = aws_iam_role.dataextractor.name
  policy_arn = aws_iam_policy.dataextractor.arn
}

# --- REPORT IAM ROLE ---
resource "aws_iam_role" "report" {
  name = "salesAnalysisReportRole"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = merge(local.common_tags, {
    Name = "salesAnalysisReportRole"
  })
}

# Report Policy
resource "aws_iam_policy" "report" {
  name        = "salesAnalysisReportPolicy"
  description = "Policy for Report Lambda to read secrets, invoke Lambda, and publish to SNS"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.aws_region}:${local.aws_account_id}:*"
      },
      {
        Sid    = "SecretsManager"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.db_url.arn,
          aws_secretsmanager_secret.db_name.arn,
          aws_secretsmanager_secret.db_user.arn,
          aws_secretsmanager_secret.db_password.arn
        ]
      },
      {
        Sid    = "LambdaInvoke"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.dataextractor.arn
      },
      {
        Sid    = "SNSPublish"
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.sales_report.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "report" {
  role       = aws_iam_role.report.name
  policy_arn = aws_iam_policy.report.arn
}

# ==========================================
# LAMBDA FUNCTIONS
# ==========================================

# --- DATA EXTRACTOR LAMBDA (VPC-Enabled) ---
resource "aws_lambda_function" "dataextractor" {
  filename         = local.lambda_dataextractor_filename
  function_name    = local.dataextractor_function_name
  role             = aws_iam_role.dataextractor.arn
  handler          = local.lambda_dataextractor_handler
  runtime          = local.lambda_runtime
  description      = "Lambda function to extract data from cafe database"
  memory_size      = local.lambda_memory_size
  timeout          = local.lambda_timeout
  
  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.dataextractor,
    aws_security_group.lambda
  ]
  
  tags = merge(local.common_tags, {
    Name = local.dataextractor_function_name
  })
}

# --- REPORT LAMBDA ---
resource "aws_lambda_function" "report" {
  filename         = local.lambda_report_filename
  function_name    = local.report_function_name
  role             = aws_iam_role.report.arn
  handler          = local.lambda_report_handler
  runtime          = local.lambda_runtime
  description      = "Lambda function to generate and send daily sales report"
  memory_size      = local.lambda_memory_size
  timeout          = local.lambda_timeout
  
  environment {
    variables = {
      topicARN = aws_sns_topic.sales_report.arn
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.report,
    aws_sns_topic.sales_report
  ]
  
  tags = merge(local.common_tags, {
    Name = local.report_function_name
  })
}

# ==========================================
# SNS TOPIC AND SUBSCRIPTION
# ==========================================

resource "aws_sns_topic" "sales_report" {
  name         = local.sns_topic_name
  display_name = local.sns_display_name
  
  tags = merge(local.common_tags, {
    Name = local.sns_topic_name
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.sales_report.arn
  protocol  = "email"
  endpoint  = local.notification_email
}

# ==========================================
# EVENTBRIDGE SCHEDULED RULE
# ==========================================

resource "aws_cloudwatch_event_rule" "daily_report" {
  name                = "DailySalesReport"
  description         = "Triggers the sales report Lambda daily at ${local.schedule_expression}"
  schedule_expression = local.schedule_expression
  
  tags = merge(local.common_tags, {
    Name = "DailySalesReport"
  })
}

resource "aws_cloudwatch_event_target" "report_lambda" {
  rule      = aws_cloudwatch_event_rule.daily_report.name
  target_id = "SalesReportLambda"
  arn       = aws_lambda_function.report.arn
  role_arn  = local.scheduler_role_arn
}

# ==========================================
# LAMBDA PERMISSIONS
# ==========================================

# Allow EventBridge to invoke Report Lambda
resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_report.arn
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}