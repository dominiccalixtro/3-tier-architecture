locals {
    availability_zones = slice(data.aws_availability_zones.availability_zones.names, 0, 2)
}