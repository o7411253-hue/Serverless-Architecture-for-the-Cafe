# AWS Café Sales Report - Terraform Infrastructure

## 📋 Overview
This Terraform project deploys a serverless daily sales report solution for a café's business operations. The infrastructure uses AWS Lambda, SNS, EventBridge, and Secrets Manager to generate and email daily sales reports without impacting the production web server performance.

## 🏗️ Architecture

### Components Deployed:
- **Lambda Functions**:
  - `salesAnalysisReportDataExtractor` - Extracts sales data from RDS (VPC-enabled)
  - `salesAnalysisReport` - Generates report and sends via SNS
- **SNS Topic**: `SalesReportTopic` with email subscription
- **EventBridge Rule**: Daily scheduled trigger at 9:30 PM UTC
- **Secrets Manager**: Stores database credentials securely
- **Security Groups**: LambdaSG with proper VPC configuration

### Architecture Diagram
┌─────────────────────────────────────────────────────────────┐
│ AWS Cloud │
│ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ VPC (10.0.0.0/16) │ │
│ │ │ │
│ │ ┌──────────────┐ ┌──────────────────┐ │ │
│ │ │ AZ A │ │ AZ B │ │ │
│ │ │ Private │ │ Private │ │ │
│ │ │ Subnet 1 │ │ Subnet 2 │ │ │
│ │ │ 10.0.1.0/24 │ │ 10.0.2.0/24 │ │ │
│ │ │ │ │ │ │ │
│ │ │ ┌────────┐ │ │ ┌────────────┐ │ │ │
│ │ │ │Lambda │ │ │ │ RDS │ │ │ │
│ │ │ │ENI │ │ │ │ Primary │ │ │ │
│ │ │ └────────┘ │ │ │ Instance │ │ │ │
│ │ └──────────────┘ │ └────────────┘ │ │ │
│ │ └──────────────────┘ │ │
│ │ │ │
│ │ ┌──────────────────────────────────────────────┐ │ │
│ │ │ DB Subnet Group │ │ │
│ │ │ ┌──────────────┐ ┌──────────────┐ │ │ │
│ │ │ │ Private │ │ Private │ │ │ │
│ │ │ │ Subnet 3 │ │ Subnet 4 │ │ │ │
│ │ │ │ 10.0.3.0/24 │ │ 10.0.4.0/24 │ │ │ │
│ │ │ └──────────────┘ └──────────────┘ │ │ │
│ │ └──────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Lambda Functions │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ salesAnalysisReportDataExtractor │ │ │
│ │ │ (VPC-Enabled - Reads RDS) │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ salesAnalysisReport │ │ │
│ │ │ (Generates & Sends Report) │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ SNS Topic │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ SalesReportTopic │ │ │
│ │ │ └── Email Subscription │ │ │
│ │ │ frank.martha@example.com │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ EventBridge Schedule │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ DailySalesReport │ │ │
│ │ │ cron(30 21 * * ? *) │ │ │
│ │ │ (9:30 PM UTC Daily) │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│ │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Secrets Manager │ │
│ │ ┌─────────────────────────────────────────────┐ │ │
│ │ │ /cafe/dbUrl │ │ │
│ │ │ /cafe/dbName │ │ │
│ │ │ /cafe/dbUser │ │ │
│ │ │ /cafe/dbPassword │ │ │
│ │ └─────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

