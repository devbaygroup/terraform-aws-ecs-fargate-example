#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "this" {
  retention_in_days = 14
  name              = "/aws/ecs/${var.service_name}"
}


resource "aws_ecs_task_definition" "this" {
  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = var.task_role
  task_role_arn            = var.task_role
  container_definitions = jsonencode(
    [
      {
        name        = var.service_name
        image       = var.image_uri
        essential   = true
        environment = []

        portMappings = [
          {
            protocol      = "tcp"
            containerPort = 80
            hostPort      = 80
          }
        ]
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.name
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "ecs"
          }
        }
      }
    ]
  )
}


resource "aws_ecs_service" "this" {
  name                               = var.service_name
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = 1
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups  = [var.alb_id]
    subnets          = var.subnet_id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.this.arn
    container_name   = var.service_name
    container_port   = 80
  }
}
