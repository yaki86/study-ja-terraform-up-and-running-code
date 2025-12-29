
resource "aws_iam_user" "example" {
  name = var.name
}

variable "name" {
  type = string
}
