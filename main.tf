#########################################################
######
####################
######
#########################################################

variable "key_name" {
  description = "The name of the EC2 key pair to use"
  default     = "thing-thang"
}

variable "key_file" {
  description = "The private key for the ec2-user used in SSH connections and by Puppet Bolt"
  default     = "~/.ssh/thing-thang.pem"
}


########################################################
###  Define VPC & Kindly Secure Networking 
########################################################

##}

resource "aws_vpc" "pupdev-vpc" {
    cidr_block 	       = "20.0.0.0/16"
    tags = {
	Name	       = "PupDev VPC"
    }
}

resource "aws_internet_gateway" "pupdev-ig" {
    vpc_id = "aws_vpc.pupdev-vpc.id"
    tags = {
  	Name	       = "PupDev Internet Gateway"
    }
}

resource "aws_network_acl" "pupdev-acl" {
    vpc_id 	       = "aws_vpc.pupdev-vpc.id"
    tags = {
    	Name           = "PupDev Network ACL"
    }
}

resource "aws_network_acl_rule" "pupdev-acl-rule" {
    network_acl_id     = "aws_network_acl.pupdev-acl.id"
    rule_number        = 100
    egress             = false
    protocol           = "-1"
    rule_action        = "allow"
    cidr_block         = "0.0.0.0/0"
    from_port          = 0
    to_port            = 65535
}

resource "aws_security_group" "pupdev-all-in" {
    vpc_id 	       = "aws_vpc.pupdev-vpc.id"
}

resource "aws_security_group_rule" "open-ssh-in" {
    type 	       = "ingress"
    from_port	       = 22 
    to_port	       = 22 
    protocol           = "tcp"
    cidr_blocks        = ["69.215.158.0/24","50.200.5.0/24","75.150.214.0/24","173.165.56.0/24"]
    security_group_id  = "aws_security_group.pupdev-all-in.id"
} 

resource "aws_security_group_rule" "open-https-out" {
    type               = "egress"
    from_port          = 443 
    to_port            = 443 
    protocol           = "tcp"
    cidr_blocks        = ["0.0.0.0/0"]
    security_group_id  = "aws_security_group.pupdev-all-in.id"
}

resource "aws_security_group_rule" "open-http-out" {
    type               = "egress"
    from_port          = 80 
    to_port            = 80 
    protocol           = "tcp"
    cidr_blocks        = ["0.0.0.0/0"]
    security_group_id  = "aws_security_group.pupdev-all-in.id"
}

resource "aws_security_group_rule" "open-ssh-out" {
    type               = "egress"
    from_port          = 22 
    to_port            = 22 
    protocol           = "tcp"
    cidr_blocks        = ["0.0.0.0/0"]
    security_group_id  = "aws_security_group.pupdev-all-in.id"
}

resource "aws_security_group_rule" "open-all-in-icmp" {
    type	       = "ingress"
    from_port 	       = 8
    to_port            = 0
    protocol           = "icmp"
    cidr_blocks        = ["0.0.0.0/0"]
    security_group_id  = "aws_security_group.pupdev-all-in.id"
}

##########################################
#####################################################




locals {
  instance_type = "t2.medium"
}

data "aws_ami" "ami" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

data "aws_ami" "windows_2012R2" {
  most_recent = "true"
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2012-R2_RTM-English-64Bit-Base-*"]
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user_data/master.sh")
}

data "template_file" "winrm" {
  template = file("${path.module}/user_data/os_win_agent.xml")
}

resource "aws_instance" "master" {
  ami           = data.aws_ami.ami.id
  instance_type = local.instance_type
  key_name      = var.key_name
  user_data     = data.template_file.user_data.rendered

  provisioner "remote-exec" {
    on_failure = continue
    inline = [
      "sudo sh -c 'while ! grep -q Cloud-init.*finished /var/log/cloud-init-output.log; do sleep 20; done'"
    ]

    connection {
      host        = self.public_ip
      user        = "ec2-user"
      private_key = file(var.key_file)
    }
  }
}

resource "aws_instance" "agent" {
  ami           = data.aws_ami.ami.id
  instance_type = local.instance_type
  key_name      = var.key_name

  provisioner "puppet" {
    use_sudo    = true
    server      = aws_instance.master.public_dns
    server_user = "ec2-user"

    connection {
      host        = self.public_ip
      user        = "ec2-user"
      private_key = file(var.key_file)
    }
  }

  depends_on = [aws_instance.master]
}



 ################################################################
##please disable windows for now, lol, preferably for all time  ##
 ################################################################
##
#resource "aws_instance" "os_win_agent" {
#  ami               = data.aws_ami.windows_2012R2.image_id
#  instance_type     = "t2.large"
#  key_name          = var.key_name
#  get_password_data = true
#
#  timeouts {
#    create = "15m"
#  }
#
#  provisioner "puppet" {
#    open_source = true
#    server      = aws_instance.master.public_dns
#    server_user = "ec2-user"
#
#    connection {
#      host     = self.public_ip
#      type     = "winrm"
#      user     = "Administrator"
#      password = rsadecrypt(self.password_data, file(var.key_file))
#      timeout  = "10m"
#    }
#  }
#
#  user_data  = data.template_file.winrm.rendered
#  depends_on = [aws_instance.master]
#}

##############################
####################
