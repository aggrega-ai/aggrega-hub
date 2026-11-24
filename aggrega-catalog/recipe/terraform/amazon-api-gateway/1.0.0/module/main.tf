# required_providers pins hashicorp/aws so the engine installs a provider
# whose resource schema this module was written against. It is a range rather
# than an exact version because every AWS body in one root configuration
# shares one installed provider, and two exact pins that differ fail init. The
# constraint string is the one the Aggrega catalog conventions' "One AWS
# provider constraint for every AWS body" section states; this file repeats it
# deliberately, because a vendored module is copied byte for byte and imports
# nothing.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.69"
    }
  }
}

# One HTTP API. Its integration, route and stage are declared beside it, and
# its custom domain and API mapping only while domain_name is set. No VPC
# link, load balancer, certificate, log group, DNS record or role is
# declared: each belongs to the operator.
resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  protocol_type = "HTTP"
  tags          = var.tags
}

# The HTTP proxy integration: every request and response passes through
# whole, on any method, with payload format 1.0, the one an integration other
# than a Lambda function's takes. Over the internet to the URL integration_uri
# names, or through the VPC link connection_id names to the listener or AWS
# Cloud Map service integration_uri names.
resource "aws_apigatewayv2_integration" "this" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.integration_uri
  payload_format_version = "1.0"
  connection_type        = var.connection_id == null ? "INTERNET" : "VPC_LINK"
  connection_id          = var.connection_id
}

# The catch-all route: a request no other route matches, which is every
# request here, goes to the integration with its full path.
resource "aws_apigatewayv2_route" "this" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.this.id}"
}

# The $default stage, served at the root of the API's endpoint, deploying
# each change to the API as it is made.
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true
  tags        = var.tags
}

# The custom domain: a Regional endpoint at TLS 1.2, presenting the
# certificate certificate_arn names, routed by API mappings alone.
resource "aws_apigatewayv2_domain_name" "this" {
  count = var.domain_name == null ? 0 : 1

  domain_name  = var.domain_name
  routing_mode = "API_MAPPING_ONLY"

  domain_name_configuration {
    certificate_arn = var.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = var.tags
}

# The API mapping sending every request for the custom domain to the
# $default stage.
resource "aws_apigatewayv2_api_mapping" "this" {
  count = var.domain_name == null ? 0 : 1

  api_id      = aws_apigatewayv2_api.this.id
  domain_name = aws_apigatewayv2_domain_name.this[0].id
  stage       = aws_apigatewayv2_stage.this.id
}

# The API's endpoint, https://<api-id>.execute-api.<region>.amazonaws.com,
# and its host.
output "endpoint" {
  value = aws_apigatewayv2_api.this.api_endpoint
}

output "host" {
  value = trimprefix(aws_apigatewayv2_api.this.api_endpoint, "https://")
}
