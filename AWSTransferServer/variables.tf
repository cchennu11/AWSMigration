variable "token" { 
}
variable "access_key" {
}
variable "secret_key" {
 }
variable "assume_role_arn" {
  default = "arn:aws:iam::689011236480:role/data_engineer"
}
variable "region" {
  default = "eu-west-2"
}
variable "transfer-logging-role" {
  default = "transfer-server-logging-role"
}
variable "transfer-role" {
  default = "transfer-server-role"
}
variable "bucket-name" {
  default = "pcbindfilesbucket"
}
variable "username" {
  default = "admin"
}
variable "function_name" {
  default = "terraform-lambda"
}
variable "handler_name" {
  default = "lambda_function"
}
variable "runtime" {
  default = "python3.7"
}
variable "timeout" {
  default = 600
}
variable "lambda_role" {
  default = "lambda-role-s3-trigger"
}