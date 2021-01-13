
provider "aws" {
  assume_role {
    role_arn    = var.assume_role_arn
    external_id = "test-account"
  }
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.region
  token      = var.token
}

resource "aws_transfer_server" "ftp-server" {
  identity_provider_type = "SERVICE_MANAGED"
  logging_role           = aws_iam_role.transfer-logging-role.arn
}

resource "aws_iam_role" "transfer-logging-role" {
  name               = var.transfer-logging-role
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "transfer.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "example" {
  name   = "transfer-logging-policy"
  role   = aws_iam_role.transfer-logging-role.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Sid": "AllowFullAccesstoCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role" "transfer-role" {
  name               = var.transfer-role
  path               = "/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "transfer.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_s3_bucket" "ftpbucket" {
  bucket = var.bucket-name
  acl    = "private"
}
resource "aws_transfer_user" "transfer-admin-user" {
  server_id = aws_transfer_server.ftp-server.id
  user_name = var.username
  role      = aws_iam_role.transfer-role.arn
  home_directory = "/${aws_s3_bucket.ftpbucket.bucket}"
  policy    = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": "arn:aws:s3:::${var.bucket-name}"
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObjectVersion",
                "s3:DeleteObject",
                "s3:GetObjectVersion"
            ],
            "Resource": "arn:aws:s3:::${var.bucket-name}/*"
        }
    ]
}

 
POLICY

}


 resource "aws_transfer_ssh_key" "ssh_key" {
  server_id = aws_transfer_server.ftp-server.id
  user_name = aws_transfer_user.transfer-admin-user.user_name
  body      = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAs6+Jd47e733azEtT2OFhmwVB3Q+wYTRWIgRRuJ6YaVCiB3a4Yhup7kj9urrX65kIrHyOcevLyFCxILVcwmM5M0xzXsODQyJLmh+t9XMzHT5Vk61RXrb+hvPeIUFGj8kEriQVZF6WweKqhJM6DVZXmhwhWjqh3pFtNBzzPevnWJz5TT33dSJBIpYe52ud8NnG9xgH+d5EsuiwVkkqs3BGGZA/imrZkkx8s/gSp8PPZcNX9q1ILSuz6Qy2SbRBp9K1ARGBafkL2Rj+tly8ocusXS4v/BhSocwYjeOdH/CeDtSQ5Iud3s1WAVDcyp3Yyqli05dyg8ZV21fRWh+zmZmW0Q== rsa-key-20210112"
}

###############
#To create S3 notifications
# fetching current account id
###############
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda-exec-role" {
  name               = var.lambda_role
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
        "Effect": "Allow",
        "Principal": {
            "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "lambda-exec-policy" {
  name   = "Lambda-S3-CW-Permission-Policy"
  role   = aws_iam_role.lambda-exec-role.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
         {
            "Effect": "Allow",
            "Action": [
                "logs:GetLogEvents",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:DescribeLogStreams",
                "logs:PutRetentionPolicy",
                "logs:CreateLogGroup"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": "arn:aws:s3:::${var.bucket-name}/*"
        }
    ]
}     
POLICY
}

###############
# Creating Lambda resource
################
resource "aws_lambda_function" "test_lambda" {
  function_name = var.function_name
  role          = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.lambda_role}"
  handler       = "${var.handler_name}.lambda_handler"
  runtime       = var.runtime
  timeout       = var.timeout
  filename      = "./src/${var.handler_name}.zip"
  environment {
    variables = {
    CreatedBy = "Terraform" }
  }
}
##################
# Adding S3 bucket as trigger to my lambda and giving the permissions
##################
resource "aws_s3_bucket_notification" "aws-lambda-trigger" {
  # bucket = "${aws_s3_bucket.bucket.id}"
  bucket = var.bucket-name
  lambda_function {
    lambda_function_arn = aws_lambda_function.test_lambda.arn
    events              = ["s3:ObjectCreated:*"]
    # filter_prefix       = "file-prefix"
    # filter_suffix       = "file-extension"
  }
}
resource "aws_lambda_permission" "test" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_lambda.function_name
  principal     = "s3.amazonaws.com"
  # source_arn = "arn:aws:s3:::${aws_s3_bucket.bucket.id}"
  source_arn = "arn:aws:s3:::${var.bucket-name}"
}
###########
# output of lambda arn
###########
output "arn" {
  value = aws_lambda_function.test_lambda.arn
}
