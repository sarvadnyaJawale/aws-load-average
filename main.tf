provider "aws" {
  region = "ap-south-1"
  access_key = "AKIA3ZZIKHCO6CD6HJYY"
  secret_key = "rz3eAu7DbsplQuPVGFcscJ+FbuzgK+hLrCpLb3tL"
}

resource "aws_vpc" "example_vpc" {
  cidr_block          = "10.0.0.0/16"
  enable_dns_support  = true
  enable_dns_hostnames = true

  tags = {
    Name = "example-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}


resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.example_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet"
  }
}


resource "aws_launch_template" "example_launch_template" {
  name          = "example-launch-template"
  image_id      = "ami-03f4878755434977f"  
  instance_type = "t2.micro"
  key_name      = "Kotak"  
  user_data     = base64encode("#!/bin/bash\napt-get update && apt-get install -y collectd")
  # Add other configuration options as needed
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "example_asg" {
  launch_template {
    id      = aws_launch_template.example_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier  = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]
  min_size             = 2
  max_size             = 5
  health_check_type    = "EC2"
}

# Scale-Out Policy (based on load average)
resource "aws_appautoscaling_policy" "scale_out" {
  name               = "scale_out_on_load_average"
  service_namespace  = "ec2"
  scalable_dimension = "ec2:autoScalingGroup:DesiredCapacity"
  resource_id        = "service/autoscaling/AutoScalingGroup:${aws_autoscaling_group.example_asg.name}"
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300  # 5-minute cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageLoadAverage"
    }
    target_value = 75.0
  }
}

# Scale-In Policy (based on load average)
resource "aws_appautoscaling_policy" "scale_in" {
  name               = "scale_in_on_load_average"
  service_namespace  = "ec2"
  scalable_dimension = "ec2:autoScalingGroup:DesiredCapacity"
  resource_id        = "service/autoscaling/AutoScalingGroup:${aws_autoscaling_group.example_asg.name}"
  policy_type        = "StepScaling"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300  # 5-minute cooldown
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# Scheduled Action for Daily Refresh
resource "aws_appautoscaling_scheduled_action" "refresh" {
  name               = "refresh"
  service_namespace  = "ec2"
  scalable_dimension = "ec2:autoScalingGroup:DesiredCapacity"
  resource_id        = "service/autoscaling/AutoScalingGroup:${aws_autoscaling_group.example_asg.name}"
  schedule           = "cron(0 12 * * ? *)"  # UTC 12am daily
  scalable_target_action {
    min_capacity       = 0
    max_capacity       = 0
  }
}

# CloudWatch Alarm for Email Notifications
resource "aws_cloudwatch_metric_alarm" "example_alarm" {
  alarm_name          = "example-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "LoadAverage"
  namespace           = "CustomMetrics"
  period              = 300
  statistic           = "Average"
  threshold           = 75.0
  alarm_actions       = ["arn:aws:sns:ap-south-1:811296503965:metric_alarm"]
}

