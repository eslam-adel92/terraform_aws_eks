################################################################################
# WAFv2 - Web Application Firewall
################################################################################
#
# This file creates a WAFv2 Web ACL for protecting the application.
#
# WAF Overview:
# - Filters HTTP/HTTPS traffic before it reaches your app
# - Blocks common attack patterns (SQLi, XSS, etc.)
# - Rate limiting to prevent DDoS
#
# How to use with ALB:
# - Add annotation to Ingress/Gateway: 
#   alb.ingress.kubernetes.io/wafv2-acl-arn: <waf_acl_arn>
#
# Rules configured:
# 1. AWS Common Rule Set - OWASP Top 10 protection
# 2. SQL Injection Rules - Database attack protection  
# 3. Known Bad Inputs - Block request smuggling, etc.
# 4. Rate Limiting - 2000 requests/5 minutes per IP
#
################################################################################

resource "aws_wafv2_web_acl" "main" {
  name        = "${var.project_name}-waf"
  description = "WAF Web ACL for ${var.project_name} - protects against common web attacks"
  scope       = "REGIONAL" # For ALB (use CLOUDFRONT for CloudFront)

  #----------------------------------------------------------------------------
  # Default Action
  #----------------------------------------------------------------------------
  # If no rules match, allow the request
  default_action {
    allow {}
  }

  #----------------------------------------------------------------------------
  # Rule 1: AWS Managed Common Rule Set
  #----------------------------------------------------------------------------
  # Protects against OWASP Top 10 vulnerabilities
  # Includes: Size restrictions, cross-site scripting, local file inclusion

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {} # Use rule group's actions (block/count)
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # Rule 2: SQL Injection Protection
  #----------------------------------------------------------------------------
  # Blocks SQL injection attempts in query strings, body, cookies

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # Rule 3: Known Bad Inputs
  #----------------------------------------------------------------------------
  # Blocks requests with known malicious patterns
  # Includes: Request smuggling, Java deserialization, host header attacks

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # Rule 4: Rate Limiting
  #----------------------------------------------------------------------------
  # Blocks IPs sending more than 2000 requests per 5 minutes
  # Helps prevent DDoS and brute force attacks

  rule {
    name     = "RateLimit"
    priority = 4

    action {
      block {} # Custom rule - we define the action
    }

    statement {
      rate_based_statement {
        limit              = 2000 # Requests per 5-minute window
        aggregate_key_type = "IP" # Track by source IP
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimit"
      sampled_requests_enabled   = true
    }
  }

  #----------------------------------------------------------------------------
  # Visibility Config
  #----------------------------------------------------------------------------
  # Enable metrics and request sampling for the entire Web ACL

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}

#------------------------------------------------------------------------------
# WAF Logging (Optional)
#------------------------------------------------------------------------------
# Uncomment to enable WAF request logging to CloudWatch Logs
#
# resource "aws_cloudwatch_log_group" "waf" {
#   name              = "aws-waf-logs-${var.project_name}"
#   retention_in_days = 30
#   tags              = local.tags
# }
#
# resource "aws_wafv2_web_acl_logging_configuration" "main" {
#   log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
#   resource_arn            = aws_wafv2_web_acl.main.arn
# }
