resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name        = var.vpc_name
    Environment = var.environment
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index % length(var.availability_zones)]
  map_public_ip_on_launch = true
  
  tags = {
    Name        = "${var.vpc_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  tags = {
    Name        = "${var.vpc_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name        = "${var.vpc_name}-public-route-table"
    Environment = var.environment
  }
}

# Route table associations for public subnets
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for private subnets (only if private subnets exist)
resource "aws_eip" "nat" {
  count = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  
  domain = "vpc"
  
  tags = {
    Name        = "${var.vpc_name}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  
  tags = {
    Name        = "${var.vpc_name}-nat-gateway"
    Environment = var.environment
  }
  
  depends_on = [aws_internet_gateway.igw]
}

# Route table for private subnets
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[0].id
  }
  
  tags = {
    Name        = "${var.vpc_name}-private-route-table"
    Environment = var.environment
  }
}

# Route table associations for private subnets
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}