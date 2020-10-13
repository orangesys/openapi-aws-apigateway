# locals {
#   resource_name_prefix = "${var.namespace}-${var.resource_tag_name}"
#   api_url              = "${aws_api_gateway_deployment._.invoke_url}${aws_api_gateway_stage._.stage_name}"
#   api_name             = "${local.resource_name_prefix}-${var.api_name}"
# }

data "template_file" "_" {
  template = var.api_template

  vars = var.api_template_vars
}

resource "aws_api_gateway_rest_api" "_" {
  name               = var.api_name
  api_key_source     = "HEADER"
  binary_media_types = var.binary_media_types
  description        = var.api_description

  body = data.template_file._.rendered

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "_" {
  rest_api_id = aws_api_gateway_rest_api._.id
  # stage_name  = ""

  triggers = {
    redeployment = sha1(data.template_file._.rendered)
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "_" {
  for_each   = var.namespace
  stage_name = each.key
  variables  = { url = each.value }

  rest_api_id   = aws_api_gateway_rest_api._.id
  deployment_id = aws_api_gateway_deployment._.id

  # xray_tracing_enabled = var.xray_tracing_enabled

  # tags = {
  #   Environment = var.namespace
  #   Name        = var.resource_tag_name
  # }
}

resource "aws_apigatewayv2_domain_name" "this" {
  count       = var.domain_name != "" ? 1 : 0
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = var.domain_name_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_route53_record" "this" {
  count   = var.domain_name != "" ? 1 : 0
  name    = aws_apigatewayv2_domain_name.this[0].domain_name
  type    = "A"
  zone_id = var.zone_id

  alias {
    name                   = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.this[0].domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_usage_plan" "myusageplan" {
  count = var.create_usage_plan ? 1 : 0
  name  = "${var.name}_usage_plan"
  api_stages {
    for_each = var.namespace
    api_id   = aws_api_gateway_rest_api._.id
    stage    = each.key
  }
}

resource "aws_api_gateway_api_key" "mykey" {
  count = var.create_usage_plan ? 1 : 0
  name  = "${var.name}_key"
}

resource "aws_api_gateway_usage_plan_key" "main" {
  count         = var.create_usage_plan ? 1 : 0
  key_id        = aws_api_gateway_api_key.mykey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.myusageplan.id
}

# resource "aws_api_gateway_method_settings" "_" {
#   rest_api_id = aws_api_gateway_rest_api._.id
#   stage_name  = aws_api_gateway_stage._.stage_name
#   method_path = "*/*"

#   settings {
#     throttling_burst_limit = var.api_throttling_burst_limit
#     throttling_rate_limit  = var.api_throttling_rate_limit
#     metrics_enabled        = var.api_metrics_enabled
#     logging_level          = var.api_logging_level
#     data_trace_enabled     = var.api_data_trace_enabled
#   }
# }
