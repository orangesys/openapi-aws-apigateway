# locals {
#   resource_name_prefix = "${var.namespace}-${var.resource_tag_name}"
#   api_url              = "${aws_api_gateway_deployment._.invoke_url}${aws_api_gateway_stage._.stage_name}"
#   api_name             = "${local.resource_name_prefix}-${var.api_name}"
# }

data "template_file" "_" {
  template = var.api_template

  # vars = var.api_template_vars
}

resource "aws_api_gateway_rest_api" "_" {
  name               = var.api_name
  api_key_source     = "HEADER"
  binary_media_types = var.binary_media_types

  body = data.template_file._.rendered
}

resource "aws_api_gateway_deployment" "_" {
  rest_api_id = aws_api_gateway_rest_api._.id
  # stage_name  = ""

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "_" {
  for_each      = var.namespace
  stage_name    = each.key
  variables     = {url = each.value}
    
  rest_api_id   = aws_api_gateway_rest_api._.id
  deployment_id = aws_api_gateway_deployment._.id

  # xray_tracing_enabled = var.xray_tracing_enabled

  # tags = {
  #   Environment = var.namespace
  #   Name        = var.resource_tag_name
  # }
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
