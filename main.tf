terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.13.0"
    }
  }
}

provider "aws" {
  profile = "default"
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "DMZ" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.10.0/24"
  map_public_ip_on_launch = "true"
}

resource "aws_internet_gateway" "GW" {
  vpc_id = aws_vpc.main.id
}

resource "aws_default_route_table" "route_table" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route = [ {
    cidr_block = "0.0.0.0/0"
    egress_only_gateway_id = ""
    gateway_id = aws_internet_gateway.GW.id
    instance_id = ""
    ipv6_cidr_block = ""
    nat_gateway_id = ""
    network_interface_id = ""
    transit_gateway_id = ""
    #vpc_endpoint_id = "value"
    vpc_peering_connection_id = ""
  } ]
}

resource "aws_security_group" "allow_tls" {
  name = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id = aws_vpc.main.id

  ingress = [ {
    description = "TLS from VPC"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []
    self = false
  }, {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []
    self = false
  }]

  egress = [ {
    description = "Allow TLS"
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 443
    protocol = "tcp"
    to_port = 443
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []
    self = false
  }, {
    description = "Allow TLS"
    cidr_blocks = [ "0.0.0.0/0" ]
    from_port = 80
    protocol = "tcp"
    to_port = 80
    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []
    self = false
  } ]

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDX4Nitmsw9aLWpNZfxtVLIy7KTxn48D3urPOIQYOxl7TtjQRvU9jtMCeMK3UIUqlhaMb2a5hAB8J4ve+8JLVi8SVFdWMd6thYk7LrquB8hFR6hYk2wm3rRMsledcafZr5S1nKgKSlO3wzQKLlsrgbf4R96Vhup7RFqVyI62stQmPrTd0tG/hIHZBSpkPNpjBU1AAUPIy+iDhYSI8tJy8sDWqME9FchwBAlgpDFnv2HtwubHJiujri1rJXO6aTQ/uqvxU62H2M4j+xNuseNs+vLB6R35EnDKGlJHrxw6daeNgNBPJmzNhVdMhDG1EUZn8Yrg2Yx2YVbgpRHc2Fu4+0Q9M28ydtpoMvRxjB67DZWNHBBS3ScKd+kLsY52UhHGVvs+XgNH9jug8glO9x+WnkRqv0jgkmhCjtLutl1HB5PvU8iw01SpOJMwlw+SecbTriSpGLdXm4Ko4THwyHyLT0ReU9BxJBcz87rnXdgSY8hk3OO/rLdNXi5U811wpdKCFk= João@Battlestation"
}

resource "aws_instance" "ssh_tunneler" {
  ami = "ami-0885b1f6bd170450c"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.DMZ.id
  vpc_security_group_ids = [ aws_security_group.allow_tls.id ]
  key_name = "deployer-key"
}

resource "aws_eip" "ip" {
  vpc = true
  instance = aws_instance.ssh_tunneler.id
}

output "ip" {
  value = aws_eip.ip.public_ip
}