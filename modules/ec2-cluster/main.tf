data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_security_group" "cluster" {
  name   = "${var.project_name}-sg-cluster"
  vpc_id = var.vpc_id

  # Allow all traffic within the same SG (Kafka/spare/Debezium talk to each other)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
        description     = "Kafka UI from Bastion"
        from_port       = 8080
        to_port         = 8080
        protocol        = "tcp"
        security_groups = [var.bastion_sg_id]
    }

    ingress {
        description     = "SSH from Bastion"
        from_port       = 22
        to_port         = 22
        protocol        = "tcp"
        security_groups = [var.bastion_sg_id]
    }





  # Allow outbound internet via NAT
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-sg-cluster"
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "kafka" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name
  associate_public_ip_address = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-kafka"
    Role = "kafka"
  })
}

resource "aws_instance" "debezium" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[1]
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name
  associate_public_ip_address = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-debezium"
    Role = "debezium"
  })
}

resource "aws_instance" "spare" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.cluster.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.key_name
  associate_public_ip_address = false

  tags = merge(var.tags, {
    Name = "${var.project_name}-spare"
    Role = "spare"
  })
}