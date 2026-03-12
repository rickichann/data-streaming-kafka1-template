Hello Richan,

Cameron here again, It was great working with you on the call. As discussed, we identified three issues preventing SSM from working on your instance i-00482d3e2924c2655 in ap-southeast-3. Here's a summary of what we found and fixed.


=========== Analysis ===========
1. SSM Agent was not installed
Your instance was launched from the Amazon Linux 2023 Minimal AMI (ami-05ba5817270c629f1). The standard AL2023 AMI comes with SSM Agent preinstalled, but the Minimal variant does not include it. We installed it manually using the commnad [1]:
$ sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm 


2. VPC endpoint security group was blocking connectivity
Your VPC has the correct interface endpoints for SSM (ssm, ssmmessages, ec2messages), and private DNS was enabled. However, the
security group attached to the VPC endpoints (sg-0b41b920454162549) did not allow inbound HTTPS (TCP 443) from the instance's private subnet. The SSM documentation states that the security group on the VPC endpoint must allow incoming connections on port 443 from the private subnet of the managed instance [2]. We resolved this by adding an inbound rule to allow TCP 443 from the VPC CIDR (10.20.0.0/16).



3. IAM instance profile
The cluster instance had the correct IAM role (da-data-streaming-2026-ec2-ssm-role) with the AmazonSSMManagedInstanceCore policy
attached [3]. We confirmed the bastion instance also needed an IAM instance profile with SSM permissions to use SSM properly.
=============================



=========== Recommendations ===========
To avoid these issues on future instance launches:

1. Use the standard Amazon Linux 2023 AMI instead of the Minimal variant, so SSM Agent is preinstalled. Alternatively, include the
dnf install amazon-ssm-agent command in your instance user data or build a custom AMI with the agent baked in.

2. Ensure the IAM instance profile with AmazonSSMManagedInstanceCore is attached to every instance you want to manage with SSM [3]. Your IAM role "da-data-streaming-2026-ec2-profile" already has this IAM profile attached to it

3. For VPC endpoints, use a dedicated security group that allows inbound TCP 443 from the subnets or security groups of your managed
instances [2]. This is cleaner than sharing the instance security group with the endpoints. However, as we already added a rule for 10.20.0.0/16 it should allow SSM access for any instance in this VPC.
=====================================



I do hope the above information helps. Thank you again or your time and patience on our call earlier and please do not hesitate to reach out if you have any questions or require further assistance. Hope you have a great rest of your day and please take care for now.

References:
[1] Manually installing SSM Agent on Amazon Linux 2 and Amazon Linux 2023 instances - https://docs.aws.amazon.com/systems-manager/latest/userguide/agent-install-al2.html 
[2] Improve the security of EC2 instances by using VPC endpoints for Systems Manager - https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html 
[3] Configure instance permissions required for Systems Manager - https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html 
[++] Find AMIs with the SSM Agent preinstalled - https://docs.aws.amazon.com/systems-manager/latest/userguide/ami-preinstalled-agent.html 

I hope the above information is helpful. If you have any further questions or run into any other issues, please don't hesitate to
reach out.

Hope you have a great rest of the day!

We value your feedback. Please share your experience by rating this and other correspondences in the AWS Support Center. You can rate a correspondence by selecting the stars in the top right corner of the correspondence.

Best regards,
Cam J.
Amazon Web Services