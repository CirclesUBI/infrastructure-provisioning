output "base_url" {
  value = "${aws_api_gateway_deployment.circles_api.invoke_url}"
}
