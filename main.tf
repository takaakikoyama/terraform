provider "aws" {
  region  = "ap-northeast-1"
  profile = "${var.profile_name}"
  version = "~> 1.43"
}

provider "null" {
  version = "~> 1.0"
}

#  VPC / networks
# ------------------------------------------------------------
resource "aws_vpc" "default" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags {
    "Name" = "default"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"

  tags {
    "Name" = "default-ig"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block  = "0.0.0.0/0"
    instance_id = "${aws_instance.bastion.id}"
  }
}

resource "aws_subnet" "public-a" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.0.0/24"
  availability_zone = "ap-northeast-1a"

  tags {
    "Name" = "public a"
  }
}

resource "aws_subnet" "public-c" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-northeast-1c"

  tags {
    "Name" = "public c"
  }
}

resource "aws_subnet" "private-a" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1a"

  tags {
    "Name" = "private a"
  }
}

resource "aws_subnet" "private-c" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-1c"

  tags {
    "Name" = "private c"
  }
}

resource "aws_route_table_association" "public-a" {
  subnet_id      = "${aws_subnet.public-a.id}"
  route_table_id = "${aws_vpc.default.main_route_table_id}"
}

resource "aws_route_table_association" "public-c" {
  subnet_id      = "${aws_subnet.public-c.id}"
  route_table_id = "${aws_vpc.default.main_route_table_id}"
}

resource "aws_route_table_association" "private-a" {
  subnet_id      = "${aws_subnet.private-a.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "private-c" {
  subnet_id      = "${aws_subnet.private-c.id}"
  route_table_id = "${aws_route_table.private.id}"
}

#  EC2
# ------------------------------------------------------------
resource "aws_instance" "bastion" {
  ami                         = "ami-0cf78ae724f63bac0"
  instance_type               = "t2.micro"
  key_name                    = "default"
  subnet_id                   = "${aws_subnet.public-a.id}"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}", "${aws_security_group.internal.id}"]
  associate_public_ip_address = true
  source_dest_check           = false

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags {
    "Name" = "bastion"
  }
}

resource "aws_eip" "bastion" {
  instance = "${aws_instance.bastion.id}"
  vpc      = true

  tags {
    Name = "bastion"
  }
}

resource "aws_instance" "web" {
  ami                         = "ami-00f9d04b3b3092052"                                                       # Amazon Linux 2
  instance_type               = "t2.micro"
  key_name                    = "default"
  subnet_id                   = "${aws_subnet.private-c.id}"
  vpc_security_group_ids      = ["${aws_security_group.private-web.id}", "${aws_security_group.internal.id}"]
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags {
    "Name" = "web"
  }
}

resource "aws_instance" "api" {
  # ami                         = "ami-06c43a7df16e8213c" # Ubuntu 16.04
  ami                         = "ami-00f9d04b3b3092052"               # Amazon Linux 2
  instance_type               = "t2.micro"
  key_name                    = "default"
  subnet_id                   = "${aws_subnet.private-c.id}"
  vpc_security_group_ids      = ["${aws_security_group.internal.id}"]
  associate_public_ip_address = false

  root_block_device {
    volume_type = "gp2"
    volume_size = 8
  }

  tags {
    "Name" = "api"
  }
}

#  ALB
# ------------------------------------------------------------
resource "aws_lb" "default" {
  name               = "default"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.alb.id}"]
  subnets            = ["${aws_subnet.public-a.id}", "${aws_subnet.public-c.id}"]
  idle_timeout       = 60

  enable_deletion_protection = false

  tags {
    Name = "web alb"
  }
}

resource "aws_lb_target_group_attachment" "web" {
  target_group_arn = "${aws_lb_target_group.web.arn}"
  target_id        = "${aws_instance.web.id}"
  port             = 80
}

resource "aws_lb_target_group" "web" {
  name     = "web"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.default.id}"

  health_check {
    interval            = 60
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = 200
  }
}

resource "aws_lb_listener" "default" {
  load_balancer_arn = "${aws_lb.default.arn}"
  port              = 80

  default_action {
    target_group_arn = "${aws_lb_target_group.web.arn}"
    type             = "forward"
  }
}

#  RDS
# ------------------------------------------------------------

resource "aws_db_instance" "main" {
  identifier                 = "${var.profile_name}-main"
  instance_class             = "db.t2.micro"
  engine                     = "mysql"
  engine_version             = "5.7.23"
  auto_minor_version_upgrade = true
  storage_type               = "gp2"
  allocated_storage          = 20
  publicly_accessible        = false
  availability_zone          = "${aws_subnet.private-c.availability_zone}"
  name                       = "${var.mysql_db}"
  username                   = "${var.mysql_user}"
  password                   = "${var.mysql_password}"
  vpc_security_group_ids     = ["${aws_security_group.internal.id}"]
  db_subnet_group_name       = "${aws_db_subnet_group.private.id}"
  backup_retention_period    = 7
  backup_window              = "03:00-03:30"
  maintenance_window         = "sun:05:00-sun:05:30"
  skip_final_snapshot        = true
}

resource "aws_db_subnet_group" "private" {
  name       = "private subnet group"
  subnet_ids = ["${aws_subnet.private-a.id}", "${aws_subnet.private-c.id}"]
}

#  security group
# ------------------------------------------------------------

resource "aws_security_group" "bastion" {
  name   = "bastion"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "bastion sg"
  }
}

resource "aws_security_group" "alb" {
  name   = "alb"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "alb sg"
  }
}

resource "aws_security_group" "public-web" {
  name   = "public web"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "public web sg"
  }
}

resource "aws_security_group" "private-web" {
  name   = "private web"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
    self            = false
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "private web sg"
  }
}

resource "aws_security_group" "internal" {
  name   = "internal"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_vpc.default.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "internal sg"
  }
}

#  S3
# ------------------------------------------------------------
// backend s3 setting
resource "aws_s3_bucket" "terraform" {
  bucket = "${var.profile_name}-terraform"

  versioning {
    enabled = true
  }

  tags {
    Name = "Terraform Backend backup"
  }
}

#  provisioning
# ------------------------------------------------------------
resource "null_resource" "bastion" {
  triggers {
    bastion_ip = "${aws_eip.bastion.public_ip}"
  }

  connection {
    type        = "ssh"
    host        = "${aws_eip.bastion.public_ip}"
    user        = "ec2-user"
    private_key = "${file(var.ssh_key_file)}"
  }

  provisioner "file" {
    source      = "${var.ssh_key_file}"
    destination = "/tmp/id_rsa"
  }

  provisioner "remote-exec" {
    script = "scripts/init_bastion.sh"
  }
}

resource "null_resource" "web" {
  triggers {
    bastion_ip = "${aws_eip.bastion.public_ip}"
    web_ip     = "${aws_instance.web.private_ip}"
  }

  connection {
    type        = "ssh"
    host        = "${aws_eip.bastion.public_ip}"
    user        = "ec2-user"
    private_key = "${file(var.ssh_key_file)}"
  }

  provisioner "file" {
    source      = "scripts/init_web.sh"
    destination = "/tmp/init_web.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'echo \"${aws_instance.web.private_ip} web\" >> /etc/hosts'",
      "scp -oStrictHostKeyChecking=no /tmp/init_web.sh web:/tmp/init.sh",
      "ssh -oStrictHostKeyChecking=no web 'bash /tmp/init.sh'",
    ]
  }
}

resource "null_resource" "api" {
  triggers {
    bastion_ip = "${aws_eip.bastion.public_ip}"
    api_ip     = "${aws_instance.api.private_ip}"
  }

  connection {
    type        = "ssh"
    host        = "${aws_eip.bastion.public_ip}"
    user        = "ec2-user"
    private_key = "${file(var.ssh_key_file)}"
  }

  provisioner "file" {
    source      = "scripts/init_api.sh"
    destination = "/tmp/init_api.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash -c 'echo \"${aws_instance.api.private_ip} api\" >> /etc/hosts'",
      "scp -oStrictHostKeyChecking=no /tmp/init_api.sh api:/tmp/init.sh",
      "ssh -oStrictHostKeyChecking=no api 'bash /tmp/init.sh'",
    ]
  }
}
