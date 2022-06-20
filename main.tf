

//ECS cluster

resource "aws_ecs_cluster" "staging" {
  name = "${var.prefix}-cluster"
}

//LB security_groups

resource "aws_security_group" "lb" {
  name        = "${var.prefix}-lb-sg"
  description = "controls access to the Application Load Balancer (ALB)"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.prefix}-tasks-sg"
  description = "allow inbound access from the ALB only"

  ingress {
    protocol        = "tcp"
    from_port       = var.port
    to_port         = var.port
    cidr_blocks     = ["0.0.0.0/0"]
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//ALB setup

resource "aws_lb" "staging" {
  name               = "${var.prefix}-alb"
  subnets            = data.aws_subnet_ids.default.ids
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]

  tags = {
    Environment = "staging"
    Application = "${var.prefix}-app"
  }
}


data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "instance_dns_name" {
  value = aws_lb.staging.dns_name
}

//ALB LISTENER

resource "aws_lb_listener" "https_forward" {
  load_balancer_arn = aws_lb.staging.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging.arn
  }
}

//Target Group for the load balancer

resource "aws_lb_target_group" "staging" {
  name        = "${var.prefix}-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "90"
    protocol            = "HTTP"
    matcher             = "200-299"
    timeout             = "20"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

//Created ECR repository

resource "aws_ecr_repository" "repo" {
  name = "${var.prefix}"
}


//ECR Lifecycle policy

resource "aws_ecr_lifecycle_policy" "repo-policy" {
  repository = aws_ecr_repository.repo.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep image deployed with tag latest",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["latest"],
        "countType": "imageCountMoreThan",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "Keep last 2 any images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 2
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}



//Task task_definition

resource "aws_ecs_task_definition" "service" {
  family                   = "${var.prefix}-task-family"
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  cpu                      = 256
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]
  container_definitions    = templatefile("./app.json.tpl", {
            aws_ecr_repository = aws_ecr_repository.repo.repository_url
            tag                = "latest"
            app_port           = 80
            region             = "${var.region}"
            prefix             = "${var.prefix}"
            envvars            = var.envvars
            port               = var.port
        })
  tags = {
    Environment = "staging"
    Application = "${var.prefix}-app"
  }
}

//Created ECS Service

resource "aws_ecs_service" "staging" {
  name            = "${var.prefix}-service"
  cluster         = aws_ecs_cluster.staging.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = data.aws_subnet_ids.default.ids
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.staging.arn
    container_name   = "${var.prefix}-app"
    container_port   = var.port
  }

  depends_on = [aws_lb_listener.https_forward, aws_iam_role_policy_attachment.ecs_task_execution_role]

  tags = {
    Environment = "staging"
    Application = "${var.prefix}-app"
  }
}

resource "aws_cloudwatch_log_group" "dummyapi" {
  name = "${var.prefix}-log-group"

  tags = {
    Environment = "staging"
    Application = "${var.prefix}-app"
  }
}

//I own this domain (thebazarpoint.com) so trying to route traffic over this domain for the test app. 
resource "aws_route53_zone" "thebazar" {
  name = "thebazarpoint.com"

  tags = {
    Environment = "staging"
  
  }
}


resource "aws_route53_record" "cname_thebazar" {
  zone_id = aws_route53_zone.thebazar.zone_id # Replace with your zone ID
  name    = "www.thebazarpoint.com" # Replace with your subdomain, Note: not valid with "apex" domains, e.g. example.com
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.staging.dns_name]
}

// Below comand will push the docker image to ECR using pipeline.

resource "null_resource" "push" {
  provisioner "local-exec" {
      command     = " chmod 755 push.sh && ./push.sh && echo Pushed_image "
     interpreter = ["bash", "-c"]
  }
}

