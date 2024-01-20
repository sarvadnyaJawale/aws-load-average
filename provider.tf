terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.11.0"
    }
  }
}

provider "aws" {
  
  region = "ap-south-1"
  access_key = "AKIA3ZZIKHCO6CD6HJYY"
  secret_key = "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"
}