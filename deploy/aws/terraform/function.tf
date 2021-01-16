resource "aws_iam_role" "iam_for_cloudquery" {
  name = "cloudquery_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "archive_file" "zip" {
  type        = "zip"
  source_dir = "../../../bin"
  output_path = "cloudquery.zip"
}


resource "aws_iam_role_policy_attachment" "cloudquery_role_attachment1" {
  role       = aws_iam_role.iam_for_cloudquery.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudquery_role_attachment2" {
  role       = aws_iam_role.iam_for_cloudquery.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "cloudquery" {
  handler       = "cloudquery"
  function_name = "cloudquery"
  filename      = "cloudquery.zip"
  runtime       = "go1.x"
  role          = aws_iam_role.iam_for_cloudquery.arn
  timeout       = 900
  memory_size   = 256

  source_code_hash = data.archive_file.zip.output_base64sha256

  vpc_config {
    subnet_ids         = [aws_subnet.rds_subnet_a.id, aws_subnet.rds_subnet_b.id]
    security_group_ids = [aws_security_group.allow_mysql.id]
  }

  environment {
    variables = {
      CQ_DRIVER= "mysql",
      CQ_DSN = "${aws_rds_cluster.cloudquery.master_username}:${aws_rds_cluster.cloudquery.master_password}@tcp(${aws_rds_cluster.cloudquery.endpoint}:3306)/cloudquery"
    }
  }
}