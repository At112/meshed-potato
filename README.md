# meshed-potato
#Deploy very simplistic REST API on Cloud of your choice (AWS, GCP, Azure, …) with IaaC. 

In this code I am deploying REST API on AWS Fargate Containers using Terraform. 

A- I developed a REST API Application in flask using python and created an image and pushed to ECR.
B- I deployed the application in Fargate containers using Terraform and enabled monitoring using cloudwatch. 
C- I created the Route53 and ALB to route the traffic to the deployed application.

Detailed instruction is in Documentation.docx file. 
