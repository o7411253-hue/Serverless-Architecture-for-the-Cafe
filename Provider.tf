
# ==========================================
# AWS PROVIDER
# ==========================================

provider "aws" {
  region = "us-east-1"
  
  
  default_tags {
    tags = {
      Project     = "CafeSalesReport"
      Environment = "prod"
      ManagedBy   = "Terraform"
      Owner       = "CloudTeam"
      CostCenter  = "Analytics"
    }
  }
}