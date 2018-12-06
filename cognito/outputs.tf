output "cognito_userpool_arn" {
  value = "${aws_cognito_user_pool.users.arn}"
}

output "cognito_userpool_id" {
  value = "${aws_cognito_user_pool.users.id}"
}

output "cognito_app_id" {
  value = "${aws_cognito_user_pool_client.circles_mobile.id}"
}
