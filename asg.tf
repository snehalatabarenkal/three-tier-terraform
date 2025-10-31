################################################################################
# Local variables
################################################################################

locals {
  user_data = <<-EOT
#!/bin/bash
yum update -y
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
yum install -y httpd
systemctl start httpd
systemctl enable httpd
usermod -a -G apache ec2-user
chown -R ec2-user:apache /var/www
chmod 2775 /var/www
find /var/www -type d -exec chmod 2775 {} \;
find /var/www -type f -exec chmod 0664 {} \;
echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php
yum install php-mbstring php-xml -y
systemctl restart httpd
systemctl restart php-fpm
cd /var/www/html
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
mkdir phpMyAdmin && tar -xvzf phpMyAdmin-latest-all-languages.tar.gz -C phpMyAdmin --strip-components 1
rm phpMyAdmin-latest-all-languages.tar.gz
cd phpMyAdmin
mv config.sample.inc.php config.inc.php
sed -i "s/localhost/${module.rds.db_instance_address}/g" config.inc.php
  EOT
}

################################################################################
# Security Group for ASG
################################################################################

module "asg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = var.asg_sg_name
  description = var.asg_sg_description
  vpc_id      = module.vpc.vpc_id

  computed_ingress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.alb_http_sg.security_group_id
    }
  ]
  number_of_computed_ingress_with_source_security_group_id = 1
  egress_rules = ["all-all"]

  tags = var.asg_sg_tags
}

################################################################################
# Autoscaling Group Module (no target_group_arns here)
################################################################################

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.0"

  # Basic settings
  name                      = var.asg_name
  min_size                  = var.asg_min_size
  max_size                  = var.asg_max_size
  desired_capacity          = var.asg_desired_capacity
  wait_for_capacity_timeout = var.asg_wait_for_capacity_timeout
  health_check_type         = var.asg_health_check_type
  vpc_zone_identifier       = module.vpc.private_subnets

  # Launch template
  create_launch_template        = true
  launch_template_name          = var.asg_launch_template_name
  launch_template_description   = var.asg_launch_template_description
  update_default_version        = var.asg_update_default_version
  image_id                      = var.asg_image_id
  instance_type                 = var.asg_instance_type
  ebs_optimized                 = var.asg_ebs_optimized
  enable_monitoring             = var.asg_enable_monitoring

  # Security
  security_groups = [module.asg_sg.security_group_id]

  # Cloud-init / user data
  user_data = base64encode(local.user_data)

  # IAM role & instance profile
  create_iam_instance_profile = var.asg_create_iam_instance_profile
  iam_role_name               = var.asg_iam_role_name
  iam_role_path               = var.asg_iam_role_path
  iam_role_description        = var.asg_iam_role_description
  iam_role_tags               = var.asg_iam_role_tags

  iam_role_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = merge(var.asg_sg_tags, {
    Name = var.asg_name
  })
}

################################################################################
# ALB Target Group Attachment (new correct method)
################################################################################

resource "aws_autoscaling_attachment" "asg_target_groups" {
  autoscaling_group_name = module.asg.autoscaling_group_name
  lb_target_group_arn    = module.alb.target_group_arns[0] # attach to first TG
}
