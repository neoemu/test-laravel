# Define SSH key pair for our instances
resource "aws_key_pair" "default" {
  key_name = "laravelkey"
  public_key = "${file("${var.key_path}")}"
}

# Define webserver inside the public subnet
resource "aws_instance" "wb" {
   ami  = "${var.ami}"
   instance_type = "t2.medium"
   key_name = "${aws_key_pair.default.id}"
   subnet_id = "${aws_subnet.public-subnet.id}"
   vpc_security_group_ids = ["${aws_security_group.sgweb.id}"]
   associate_public_ip_address = true
   source_dest_check = false
   user_data = "${file("install.sh")}"

  tags {
    Name = "laravel-web"
  }
}

# Define webserver inside the public subnet2
resource "aws_instance" "wb2" {
   ami  = "${var.ami}"
   instance_type = "t2.medium"
   key_name = "${aws_key_pair.default.id}"
   subnet_id = "${aws_subnet.public-subnet2.id}"
   vpc_security_group_ids = ["${aws_security_group.sgweb.id}"]
   associate_public_ip_address = true
   source_dest_check = false
   user_data = "${file("install.sh")}"

  tags {
    Name = "laravel-web2"
  }
}

module "elb_http" {
  source = "terraform-aws-elb"

  name = "elb-laravel"

  subnets         = ["${aws_subnet.public-subnet.id}", "${aws_subnet.public-subnet2.id}"]
  security_groups = ["${aws_security_group.sgweb.id}"]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "HTTP"
      lb_port           = "80"
      lb_protocol       = "HTTP"
    },
  ]

  health_check = [
    {
      target              = "HTTP:80/"
      interval            = 30
      healthy_threshold   = 2
      unhealthy_threshold = 2
      timeout             = 5
    },
  ]

#  access_logs = [
#    {
#      bucket = "my-access-logs-bucket"
#    },
#  ]

  number_of_instances = 2
  instances           = ["${aws_instance.wb.id}", "${aws_instance.wb2.id}"]
  
  tags = {
    Owner       = "user"
    Environment = "dev"
  }
}

module "db" {
  source = "terraform-aws-rds"

  identifier = "demodb"

  # All available versions: http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html#MySQL.Concepts.VersionMgmt
  engine            = "mysql"
  engine_version    = "5.7.21"
  instance_class    = "db.t2.micro"
  allocated_storage = 5
  storage_encrypted = false

  # kms_key_id        = "arm:aws:kms:<region>:<accound id>:key/<kms key id>"
  name     = "demodb"
  username = "rmb"
  password = "teste123"
  port     = "3306"

  vpc_security_group_ids = ["${aws_security_group.sgdb.id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster
  backup_retention_period = 0

  tags = {
    Owner       = "user"
    Environment = "dev"
  }

  # DB subnet group
  subnet_ids = ["${aws_subnet.public-subnet.id}", "${aws_subnet.private-subnet.id}"]

  # DB parameter group
  family = "mysql5.7"

  # DB option group
  major_engine_version = "5.7"

  # Snapshot name upon DB deletion
  final_snapshot_identifier = "demodb"

  options = [
    {
      option_name = "MARIADB_AUDIT_PLUGIN"

      option_settings = [
        {
          name  = "SERVER_AUDIT_EVENTS"
          value = "CONNECT"
        },
        {
          name  = "SERVER_AUDIT_FILE_ROTATIONS"
          value = "37"
        },
      ]
    },
  ]
}
