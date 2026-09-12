# The load balancer is internet-facing by design: it is the public entry point of
# a three-tier web application. Everything behind it - the web tier and the
# database - sits in private and database subnets with no route in from the
# internet. What matters is that this single exposed surface is hardened, which
# is what the settings below do.
resource "aws_lb" "app_alb" {
  # checkov:skip=CKV2_AWS_76:AWSManagedRulesKnownBadInputsRuleSet, which carries the Log4j rules, is attached at priority 2 on the web ACL associated with this load balancer. The graph check does not follow the association through this module.
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets_ids

  # Reject requests carrying malformed headers instead of normalising and
  # forwarding them. Header desync between the load balancer and the target is
  # the basis of request-smuggling attacks.
  drop_invalid_header_fields = true

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
}

# --------------------------------------------------------- access logging ----

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "current" {}

resource "aws_s3_bucket" "alb_logs" {
  # checkov:skip=CKV_AWS_18:This bucket is the access-log destination. Enabling S3 access logging on the log bucket itself creates a recursive logging target and is not useful at this scale.
  # checkov:skip=CKV_AWS_144:Cross-region replication of load balancer logs is a durability requirement this project does not have, and it doubles storage cost.
  # checkov:skip=CKV_AWS_145:Load balancer log delivery supports SSE-S3 or SSE-KMS with a customer-managed key only - it cannot write to a bucket encrypted with the AWS-managed S3 key. AES256 is the option that keeps log delivery working without standing up and paying for a CMK.
  # checkov:skip=CKV2_AWS_62:Event notifications drive downstream processing. Nothing consumes these logs on write; they are read on demand during an investigation.
  bucket        = "${var.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  # ap-southeast-1 and other older regions deliver load balancer logs as a
  # regional ELB account principal rather than the logdelivery service
  # principal, which is what aws_elb_service_account resolves.
  statement {
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.current.arn]
    }

    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
  }

  statement {
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.alb_logs.arn,
      "${aws_s3_bucket.alb_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

# ------------------------------------------------------------------- WAF ----

# A public ALB with no WAF means every request reaches the application. The AWS
# managed rule sets cover the common injection and bad-input cases and the
# known-bad-inputs list, which is the floor for an internet-facing endpoint.
resource "aws_wafv2_web_acl" "this" {
  # checkov:skip=CKV2_AWS_31:Logging is configured below via aws_wafv2_web_acl_logging_configuration. The graph check does not resolve the association across this module boundary.
  name        = "${var.name_prefix}-alb-acl"
  description = "Managed rule baseline for the public ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-alb-acl"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = aws_lb.app_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# WAF logging. The log group name must begin with "aws-waf-logs-"; WAF rejects
# any other destination name.
resource "aws_cloudwatch_log_group" "waf" {
  # checkov:skip=CKV_AWS_158:Sampled request metadata, encrypted at rest with an AWS-owned key. A customer-managed key adds cost and key-policy surface without changing the exposure.
  # checkov:skip=CKV_AWS_338:Retention follows the load balancer log retention variable rather than a one-year compliance target.
  name              = "aws-waf-logs-${var.name_prefix}-alb"
  retention_in_days = var.log_retention_days
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  # Request headers can carry session cookies and bearer tokens. Redacting them
  # keeps a WAF log from becoming a credential store.
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

resource "aws_lb_target_group" "this" {
  name     = "${var.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}