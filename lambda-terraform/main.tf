provider "aws" {
  region = "us-east-1"
}

# Zip lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach policy to write to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Add SQS policy for Lambda to poll the queue
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda_sqs_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.my_queue.arn
      }
    ]
  })
}

# SQS Queue
resource "aws_sqs_queue" "my_queue" {
  name = "my_lambda_queue"
}

# Lambda Function Resource
resource "aws_lambda_function" "my_lambda" {
  function_name    = "MyLambdaWithLogging"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Lambda Event Source Mapping for SQS
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.my_queue.arn
  function_name    = aws_lambda_function.my_lambda.arn
  enabled          = true
  batch_size       = 10
}

# EventBridge Rule to trigger Lambda (example schedule)
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "every_minute_rule"
  schedule_expression = "rate(1 minute)"
}

# Target Lambda in EventBridge Rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "lambda_target"
  arn       = aws_lambda_function.my_lambda.arn
}

# Permission for EventBridge to invoke Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.my_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}
