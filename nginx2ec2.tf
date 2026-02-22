#configure aws provider for two region
provider "aws" {
 alias = "us_east_1"
 region = "us-east-1"
}

provider "aws" {
 alias = "ap_south_1"
 region = "ap-south-1"
}

#VPCs
resource "aws_vpc" "vpc_us" {
  provider = aws.us_east_1
  cidr_block = "10.0.0.0/16"
  tags = { name = "VPC-US" }
}

resource "aws_vpc" "vpc_ap" {
  provider = aws.ap_south_1
  cidr_block = "10.0.0.0/16"
  tags = { name = "VPC-AP" }
}

#subnets
resource "aws_subnet" "subnet_us" {
  provider = aws.us_east_1
  vpc_id = aws_vpc.vpc_us.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = { name = "subnet-us" }
}

resource "aws_subnet" "subnet_ap" {
  provider = aws.ap_south_1
  vpc_id = aws_vpc.vpc_ap.id
  cidr_block = "10.0.1.0/24"
  availability_zone =  "ap-south-1a"
  map_public_ip_on_launch = true
  tags = { name = "subnet-ap" }
}

#security groups
resource "aws_security_group" "sg_us" {
  provider = aws.us_east_1
  name = "web-sg-us"
  description = "Allow SSH and HTTP"
  vpc_id = aws_vpc.vpc_us.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { name = "SG-US" }
}

resource "aws_security_group" "sg_ap" {
  provider = aws.ap_south_1
  name = "web-sg-ap"
  description = "Allow SSH and HTTP"
  vpc_id = aws_vpc.vpc_ap.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { name = "SG-AP" }
}

# Internet Gateway for us-east-1
resource "aws_internet_gateway" "igw_us" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.vpc_us.id
  tags = { Name = "IGW-US" }
}

# Route Table for us-east-1
resource "aws_route_table" "rt_us" {
  provider = aws.us_east_1
  vpc_id   = aws_vpc.vpc_us.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_us.id
  }

  tags = { Name = "RT-US" }
}

# Associate Route Table with Subnet (us-east-1)
resource "aws_route_table_association" "rta_us" {
  provider       = aws.us_east_1
  subnet_id      = aws_subnet.subnet_us.id
  route_table_id = aws_route_table.rt_us.id
}

# Internet Gateway for ap-south-1
resource "aws_internet_gateway" "igw_ap" {
  provider = aws.ap_south_1
  vpc_id   = aws_vpc.vpc_ap.id
  tags = { Name = "IGW-AP" }
}

# Route Table for ap-south-1
resource "aws_route_table" "rt_ap" {
  provider = aws.ap_south_1
  vpc_id   = aws_vpc.vpc_ap.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_ap.id
  }

  tags = { Name = "RT-AP" }
}

# Associate Route Table with Subnet (ap-south-1)
resource "aws_route_table_association" "rta_ap" {
  provider       = aws.ap_south_1
  subnet_id      = aws_subnet.subnet_ap.id
  route_table_id = aws_route_table.rt_ap.id
}

# Key Pair for us-east-1
resource "aws_key_pair" "kp_us" {
  provider   = aws.us_east_1
  key_name   = "my-key-us"
  public_key = file("~/.ssh/id_rsa.pub")   # path to your public key
}

# Key Pair for ap-south-1
resource "aws_key_pair" "kp_ap" {
  provider   = aws.ap_south_1
  key_name   = "my-key-ap"
  public_key = file("~/.ssh/id_rsa.pub")   # same public key file
}

#1st EC2 instance
resource "aws_instance" "web_us" {
 provider = aws.us_east_1
 ami = "ami-0f3caa1cf4417e51b"
 instance_type = "t3.micro"
 subnet_id = aws_subnet.subnet_us.id
 vpc_security_group_ids = [aws_security_group.sg_us.id]
 key_name               = aws_key_pair.kp_us.key_name
 
 user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "nginx-us-east"
  }
}

#2nd EC2 instance
resource "aws_instance" "web_ap" {
 provider = aws.ap_south_1
 ami = "ami-051a31ab2f4d498f5"
 instance_type = "t3.micro"
 subnet_id     = aws_subnet.subnet_ap.id
 vpc_security_group_ids = [aws_security_group.sg_ap.id]
 key_name               = aws_key_pair.kp_ap.key_name
 
 user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    Name = "nginx-us-west"
  }
}

output "us_instance_public_ip" {
  value = aws_instance.web_us.public_ip
}

output "ap_instance_public_ip" {
  value = aws_instance.web_ap.public_ip
}
