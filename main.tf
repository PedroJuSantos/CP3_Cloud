# Configuração do Provider AWS
provider "aws" {
  region    = "us-east-1" # Substitua pela região desejada
  access_key    =  "aws_access_key_id"
  secret_key    =  "aws_secret_access_key" 
  token = "aws_session_token"
}

# 1. Criar uma VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

# 2. Criar uma Sub-rede Privada
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.0.0/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
}

# 3. Criar duas Sub-redes Públicas (em duas Zonas de Disponibilidade)
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/28"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/28"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# 4. Criar um Internet Gateway e associar à VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# 5. Criar Tabela de Rotas e associar com as Sub-redes Públicas
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_rt_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_rt_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Criar Grupos de Segurança para EC2 e RDS
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

# 7. Criar Instância RDS (PostgreSQL)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "mydbsubnetgroup"
  subnet_ids = [aws_subnet.private_subnet.id]
}

resource "aws_db_instance" "rds_instance" {
  identifier              = "mydbinstance"
  allocated_storage       = 20
  engine                  = "postgres"
  instance_class          = "db.t2.micro"
  name                    = "mydatabase"
  username                = "admin"
  password                = "mypassword"
  vpc_security_group_ids  = [aws_security_group.rds_sg.id]
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  publicly_accessible     = false
}

# 8. Criar Instâncias EC2 em cada Sub-rede Pública
resource "aws_instance" "ec2_instance_1" {
  ami                    = "ami-0abcdef1234567890" # Substitua pelo ID da AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  security_groups        = [aws_security_group.ec2_sg.name]
  associate_public_ip_address = true
  key_name               = "my-key-pair" # Substitua pela sua chave SSH
}

resource "aws_instance" "ec2_instance_2" {
  ami                    = "ami-0abcdef1234567890" # Substitua pelo ID da AMI
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public_subnet_2.id
  security_groups        = [aws_security_group.ec2_sg.name]
  associate_public_ip_address = true
  key_name               = "my-key-pair" # Substitua pela sua chave SSH
}
