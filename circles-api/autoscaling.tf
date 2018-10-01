resource "aws_appautoscaling_target" "circles_api" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  role_arn           = "${aws_iam_role.ecs_autoscale_role.arn}"
  min_capacity       = 1
  max_capacity       = 4
}

resource "aws_appautoscaling_policy" "api_up" {
  name                    = "${var.project_prefix}-asg-policy-up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

resource "aws_appautoscaling_policy" "api_down" {
  name                    = "${var.project_prefix}-asg-policy-down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.circles_api.name}/${aws_ecs_service.circles_api.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.circles_api"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "api_cpu_high" {
  alarm_name          = "${var.project_prefix}-cpu-utilization-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "85"

  dimensions {
    ClusterName = "${aws_ecs_cluster.circles_api.name}"
    ServiceName = "${aws_ecs_service.circles_api.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.api_up.arn}"]
  ok_actions    = ["${aws_appautoscaling_policy.api_down.arn}"]
}