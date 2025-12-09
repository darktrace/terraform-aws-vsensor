## Overview

This Quick Start terraform module deploys Darktrace vSensor on the Amazon Web Services (AWS) Cloud. 

Darktrace vSensor probes analyze raw data from mirrored virtual private cloud (VPC) traffic permitting a connected Darktrace service to learn to identify traffic patterns and threats. Darktrace vSensors are only used in conjunction with a Darktrace cloud service offering or physical Darktrace appliance. 

Darktrace vSensors accept traffic from mirroring services (such as AWS Traffic mirroring) and from Darktrace osSensor agents. Darktrace osSensors can be configured on virtual machines and containerized applications. Darktrace osSensors are available for Linux, Windows, and any system that can run the Docker Engine. 

Darktrace vSensors can also be configured to accept syslog feeds of third-party security information and event management tools.

Darktrace vSensors extract meta-data from the traffic sources and submit these to a connected Darktrace cloud service or physcial Darktrace deployment over port 443 (TLS). PCAP (packet capture) data is produced by the vSensor for forensic analysis. This is stored in an Amazon Simple Storage Service (Amazon S3) bucket.

This guide covers the steps necessary to deploy this Quick Start.


## Architecture Diagram

![image](./source/architecture-diagram.png)

This module sets up the following:

- A highly available architecture (when 2+ Availability Zones are used).

- (Optional) A virtual private network (VPC) configured with public and private subnets, according to AWS best practices, to provide you with your own virtual network on AWS.

- In the public subnets:
  - Managed network address translation (NAT) gateways<sup>*</sup> to allow outbound internet access to Darktrace vSensor instances.
  - Linux bastion host<sup>*</sup> managing inbound Secure Shell (SSH) access to Darktrace vSensor instances in the private subnets.

- In the private subnets:
  - An Auto Scaling group of Darktrace vSensor probes hosted on Amazon EC2 instances.

- VPC traffic mirroring to send mirrored traffic to a Network Load Balancer.

- A Network Load Balancer to distribute monitored VPC traffic to Darktrace vSensor instances.

- An Amazon S3 bucket to store packets captured by Darktrace vSensor.

- Amazon CloudWatch to provide:
  - Logs from Darktrace vSensor EC2 instances.
  - Metrics from Darktrace vSensor EC2 instances.

- (Optional) [AWS Systems Manager Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager.html) to manage the vSensors through an interactive one-click browser-based shell or through the AWS CLI.

<sub><sup>*</sup> If the module does not create a new VPC the components marked by asterisks will be skipped.</sub>

## Deployment options

This Quick Start terraform module provides the following deployment options:

- Deploy Darktrace vSensor into an existing VPC. This option provisions Darktrace vSensor in your existing AWS infrastructure.

- Deploy Darktrace vSensor into a new VPC. This option builds a new AWS environment that consists of the VPC, subnets, NAT gateways, security groups, bastion host (optional), and other infrastructure components. It then deploys Darktrace vSensor into this new VPC.

AWS System Manager Session Manager for access to the vSensors can be enabled in any of the deployments. This works independently from the bastion host deployed by the module, or any remote access provided outside the module. [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/what-is-systems-manager.html#capabilities-operations-management) provides secure and auditable edge device and instance management without needing to open inbound ports, maintain bastion hosts, or manage SSH keys.

To minimise traffic costs, Cross-Zone Load Balancing is disabled by default. This will require at least one vSensor in each Availabily Zone you need to monitor. There is an option to enable Cross-Zone Load Balancing (see input variable `cross_zone_load_balancing_enable` for details).

## Pre deployment steps

### Register a push token and obtain a Darktrace vSensor update key.

Register a new push token to enable connection between vSensor probes and an existing Darktrace on-premise or cloud instance. All of the vSensor instances in one deployment should share the same push token.

1. Log into the Darktrace console.

2. From the main menu, choose Admin > System Config, then access the "Settings" page.

3. Locate the "Push Probe Tokens" section. At the bottom of the list of probes is an field to create a new token. Enter a label for the vSensor deployment.

4. Choose Add. You will need to record two variables from the resulting window. The vSensor Update Key (also found on the Darktrace customer portal) and the Push Token. The Push Token is only displayed once.

5. In AWS Systems Manager (Parameter Store) create a new parameter with a unique name eg. `darktrace_vsensor_update_key` with type SecureString and the value of the vSensor Update Key obtained previously.

6. In AWS Systems Manager (Parameter Store) create a new parameter with a unique name, eg. `darktrace_push_token` with type SecureString and the value of the Push Token obtained previously. (Any additional Darktrace master deployments will require their own push token)


If you have a physical Darktrace deployment behind a firewall, you must grant access to the instance to the IP addresses of your NAT Gateways after deployment.

Note: Darktrace cloud offerings are already configured to allow Push Token access, no firewall changes are necessary.

### Set osSensor shared HMAC secret key

The shared HMAC secret key between the osSensor and vSensor is optional for the installation. If the HMAC is not provided the module will not set the osSensor shared HMAC secret key on the vSensors.

This can be done outside the module once the deployment has completed. More details on how to do it can be found in the [Requirements](https://customerportal.darktrace.com/product-guides/main/ossensor-docker-introduction) section in the osSensor product guide on the Darktrace Customer Portal. 

1. In AWS Systems Manager (Parameter Store) create a new parameter with a unique name, eg. `os_sensor_hmac_token` with type SecureString and the value of the osSensor shared HMAC secret key obtained previously.

### Terraform user policy

The terraform user's IAM policy should allow the relevant actions as per the resources the module will create.

## Usage

### Before you start

If you use the module to create a new VPC the number of `availability_zone`, `private_subnets_cidrs`, and `public_subnets_cidrs` should be the same. Changing the order will force re-creating the resources.

### Deploy Darktrace vSensor into an existing VPC
```
module "vsensors" {
  source = "git::https://github.com/darktrace/terraform-aws-vsensor?ref=<version>"

  deployment_prefix = "dt"

  vpc_id              = "vpc-XXXX"
  vpc_private_subnets = ["subnet-XXXXXXX", "subnet-YYYYYYY"]

  update_key           = "update_key_parameter_store_name"
  push_token           = "push_token_parameter_store_name"
  instance_host_name   = "instance_host_name-XXXXXXX"
  os_sensor_hmac_token = "os_sensor_hmac_token_parameter_store_name"
}
```

### Deploy Darktrace vSensor into a new VPC

```
module "vsensors" {
  source = "git::https://github.com/darktrace/terraform-aws-vsensor?ref=<version>"

  deployment_prefix = "dt"

  vpc_enable            = true
  vpc_cidr              = "10.0.0.0/16"
  availability_zone     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets_cidrs = ["10.0.0.0/23", "10.0.2.0/23", "10.0.4.0/23"]
  public_subnets_cidrs  = ["10.0.246.0/23", "10.0.248.0/23", "10.0.250.0/23"]

  update_key           = "update_key_parameter_store_name"
  push_token           = "push_token_parameter_store_name"
  instance_host_name   = "instance_host_name-XXXXXXX"
}
```

### Deploy Darktrace vSensor into a new VPC with bastion host

```
module "vsensors" {
  source = "git::https://github.com/darktrace/terraform-aws-vsensor?ref=<version>"

  deployment_prefix = "dt"

  vpc_enable            = true
  vpc_cidr              = "10.0.0.0/16"
  availability_zone     = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  private_subnets_cidrs = ["10.0.0.0/23", "10.0.2.0/23", "10.0.4.0/23"]
  public_subnets_cidrs  = ["10.0.246.0/23", "10.0.248.0/23", "10.0.250.0/23"]

  ssh_keyname = "sshkey-XXXXXX"

  ssm_session_enable = false

  instance_type = "m5.large"

  desired_capacity = 3
  max_size         = 5
  min_size         = 3

  update_key           = "update_key_parameter_store_name"
  push_token           = "push_token_parameter_store_name"
  instance_host_name   = "instance_host_name-XXXXXXX"
  os_sensor_hmac_token = "os_sensor_hmac_token_parameter_store_name"

  bastion_enable        = true
  bastion_instance_type = "t3.micro"
  bastion_ami           = "Ubuntu-Server-24_04-LTS-HVM"
  bastion_ssh_keyname   = "sshkey-XXXYYY"
  bastion_ssh_cidrs     = ["35.180.11.224/27"]
  tags = {
    department    = "Ops"
    team          = "Ops-1"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.23 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.23 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.5 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.vsensors_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.vsensors_asg_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_cloudwatch_log_group.vsensor_log_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ec2_traffic_mirror_filter.vsensor_filter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_traffic_mirror_filter) | resource |
| [aws_ec2_traffic_mirror_filter_rule.rulein](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_traffic_mirror_filter_rule) | resource |
| [aws_ec2_traffic_mirror_filter_rule.ruleout](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_traffic_mirror_filter_rule) | resource |
| [aws_ec2_traffic_mirror_target.vsensor_lb_target](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_traffic_mirror_target) | resource |
| [aws_eip.remote_access_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip.vsensor_nat_gw_eip](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_eip_association.remote_access_eip_assoc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip_association) | resource |
| [aws_iam_instance_profile.vsensor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.vsensor_iam](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.vsensor_iam](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.vsensor_iam](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_internet_gateway.main_igw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_kms_alias.vsensor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.vsensor_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_launch_template.vsensor](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_lb.vsensor_lb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.vsensor_lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.vsensor_tg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_nat_gateway.vsensor_nat_gw](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route_table.main_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.vsensor_rt](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.public_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.vsensor_rta](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_security_group.bastion_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vsensors_asg_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.allow_mirror_4789](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.allow_ossesnsors_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.allow_ossesnsors_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.bastion_ssh_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.bastion_to_any](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.remote_ssh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ssh_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.to_pkgs_443](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.to_pkgs_80](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ssm_document.session_manager_preferences](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_document) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [random_string.rnd_deploy_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [aws_ami.bastion_amazon_linux_2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.bastion_ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.vsensor_iam](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.vsensor_pcaps_s3](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.dt_os_sensor_hmac_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.dt_push_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_ssm_parameter.dt_update_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |
| [aws_vpc.vsensors_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zone"></a> [availability\_zone](#input\_availability\_zone) | If `vpc_enable = true` - Availability Zones that the vSensors, the NAT Gateways and all resources will be deployed into. | `list(string)` | <pre>[<br>  "us-east-1a",<br>  "us-east-1b"<br>]</pre> | no |
| <a name="input_bastion_ami"></a> [bastion\_ami](#input\_bastion\_ami) | (Optional) The AMI operating system for the bastion host. This can be one of Amazon-Linux2023-HVM, Ubuntu-Server-24\_04-LTS-HVM.<br>  Default user names: for Amazon-Linux2023-HVM the user name is `ec2-user`, for Ubuntu-Server-24\_04-LTS-HVM the user name is `ubuntu`. | `string` | `"Amazon-Linux2023-HVM"` | no |
| <a name="input_bastion_enable"></a> [bastion\_enable](#input\_bastion\_enable) | If `true` will create a public Bastion.<br>  (Optional; applicable only if `vpc_enable = true`) If **true** a standalone/single bastion host will be installed to provide ssh remote access to the vSensors.<br>  It will be installed in the first Public subnet CIDR (`public_subnets_cidrs`). The bastion will automatically have ssh access to the vSensors. | `bool` | `false` | no |
| <a name="input_bastion_instance_type"></a> [bastion\_instance\_type](#input\_bastion\_instance\_type) | (Optional) The ec2 instance type for the bastion host. This can be one of t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge. | `string` | `"t3.micro"` | no |
| <a name="input_bastion_ssh_cidrs"></a> [bastion\_ssh\_cidrs](#input\_bastion\_ssh\_cidrs) | (Optional) Allowed CIDR blocks for SSH (Secure Shell) access to the bastion host. | `list(any)` | `[]` | no |
| <a name="input_bastion_ssh_keyname"></a> [bastion\_ssh\_keyname](#input\_bastion\_ssh\_keyname) | (Optional) Name of the ssh key pair stored in AWS. This key will be added to the vSensor ssh configuration.<br>  Use case to not provide ssh key pair name - when it is desirable the access to vSensors to be via AWS System Manager Session only (see ssm\_session\_enable). | `string` | `null` | no |
| <a name="input_cloudwatch_logs_days"></a> [cloudwatch\_logs\_days](#input\_cloudwatch\_logs\_days) | Number of days to retain vSensor CloudWatch logs. <br>  Allowed values are 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0.<br>  If you select 0, the events in the log group are always retained and never expire. | `number` | `30` | no |
| <a name="input_cross_zone_load_balancing_enable"></a> [cross\_zone\_load\_balancing\_enable](#input\_cross\_zone\_load\_balancing\_enable) | (Optional) Enable (true) or disable (false) cross-zone load balancing of the load balancer.<br>  If it is disabled, make sure there is **at least one** vSensor in each Availability Zone with Mirror sources.<br>  This will also configure the NLB 'Client routing policy' to `any availability zone` when `cross_zone_load_balancing_enable = true`,<br>  or to `availability zone affinity` when `cross_zone_load_balancing_enable = false`.<br>  For more information about cross-zone load balancing see the AWS documentation: [Network Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html#cross-zone-load-balancing),<br>  [Cross-zone load balancing for target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-cross-zone.html),<br>  [Cross-zone load balancing](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html#cross-zone-load-balancing),<br>  [Announcing new AWS Network Load Balancer (NLB) availability and performance capabilities](https://aws.amazon.com/about-aws/whats-new/2023/10/aws-nlb-availability-performance-capabilities/).<br>  Default is disable cross-zone load balancing. | `bool` | `false` | no |
| <a name="input_cw_log_group_name"></a> [cw\_log\_group\_name](#input\_cw\_log\_group\_name) | (Optional) CloudWatch Log Group name for the vSensor logs.<br>  [Naming restrictions](https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html#description) apply.<br>  If not provided the deployment ID (`deployment_id`) will be used. | `string` | `""` | no |
| <a name="input_cw_metrics_enable"></a> [cw\_metrics\_enable](#input\_cw\_metrics\_enable) | (Optional) If true (default) a Custom Namespace for vSensor CloudWatch Metrics will be created. | `bool` | `true` | no |
| <a name="input_cw_namespace"></a> [cw\_namespace](#input\_cw\_namespace) | (Optional) CloudWatch Metrics Namespace for the vSensors (if `cw_metrics_enable = true`), for example vSensorMetrics.<br>  [Naming restrictions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html) apply.<br>  If not provided the deployment ID (`deployment_id`) will be used. | `string` | `""` | no |
| <a name="input_deployment_prefix"></a> [deployment\_prefix](#input\_deployment\_prefix) | (Forces re-creating all resources) Two letter (lowercase) prefix that will be used to create a unique deployment ID to identify the resources. | `string` | n/a | yes |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | Desired number of vSensor instances in the Auto-Scaling group. | `number` | `2` | no |
| <a name="input_filter_dest_cidr_block"></a> [filter\_dest\_cidr\_block](#input\_filter\_dest\_cidr\_block) | Destination CIDR for the Traffic Mirror filter. Use the default `0.0.0.0/0` for all traffic. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_filter_src_cidr_block"></a> [filter\_src\_cidr\_block](#input\_filter\_src\_cidr\_block) | Source CIDR for the Traffic Mirror filter. Use the default `0.0.0.0/0` for all traffic. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_instance_host_name"></a> [instance\_host\_name](#input\_instance\_host\_name) | Host name of the Darktrace Master instance. | `string` | n/a | yes |
| <a name="input_instance_port"></a> [instance\_port](#input\_instance\_port) | Connection port between vSensor and the Darktrace Master instance. | `number` | `443` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | Specify the EC2 instance type that will be used in the Auto-Scaling Group. It is recommended to start with `t3.medium`, change if you expect frequent high traffic. | `string` | `"t3.medium"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of the kms key for encrypting log data in CloudWatch Logs. This is when the kms key is created outside the module.<br>  The key policy should allow log encryption see [AWS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html).<br>  If `kms_key_enable` is true then this kms key arn will be ignored. | `string` | `null` | no |
| <a name="input_kms_key_enable"></a> [kms\_key\_enable](#input\_kms\_key\_enable) | If true (default) the module will create a new kms key for encrypting log data in CloudWatch Logs. If false, `kms_key_arn` should be provided. | `bool` | `true` | no |
| <a name="input_kms_key_rotation"></a> [kms\_key\_rotation](#input\_kms\_key\_rotation) | Specifies whether key rotation is enabled. Defaults to false. | `bool` | `false` | no |
| <a name="input_lifecycle_pcaps_s3_bucket"></a> [lifecycle\_pcaps\_s3\_bucket](#input\_lifecycle\_pcaps\_s3\_bucket) | Number of days to retain captured packets in Amazon S3. Longer retention will increase storage costs. Set to 0 to disable PCAP storage. | `number` | `7` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of vSensor instances in the Auto-Scaling group. | `number` | `5` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of vSensor instances in the Auto-Scaling group. Recomended number is not to be less than the number of Availability Zone where the vSensors will be deployed into. | `number` | `2` | no |
| <a name="input_os_sensor_hmac_token"></a> [os\_sensor\_hmac\_token](#input\_os\_sensor\_hmac\_token) | (Optional) Name of the SSM Parameter Store parameter that stores the hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor.<br>  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),<br>  period (.), hyphen (-), and underscore (\_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.<br>  **Note**: for security reasons the HMAC should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform. | `string` | `""` | no |
| <a name="input_private_subnets_cidrs"></a> [private\_subnets\_cidrs](#input\_private\_subnets\_cidrs) | If `vpc_enable = true` - CIDRs for the private subnets that will be created for the vSensors. | `list(string)` | <pre>[<br>  "10.0.0.0/19",<br>  "10.0.32.0/19"<br>]</pre> | no |
| <a name="input_proxy"></a> [proxy](#input\_proxy) | (Optional) A proxy if it is required for the vSensor to access the Darktrace Master instance.<br>  It should be specified in the format http://hostname:port with no authentication, or http://user:pass@hostname:port with authentication. | `string` | `""` | no |
| <a name="input_public_subnets_cidrs"></a> [public\_subnets\_cidrs](#input\_public\_subnets\_cidrs) | If `vpc_enable = true` - CIDRs for the public subnets that will be created for the NAT Gateways. | `list(string)` | <pre>[<br>  "10.0.128.0/20",<br>  "10.0.144.0/20"<br>]</pre> | no |
| <a name="input_push_token"></a> [push\_token](#input\_push\_token) | Name of parameter in the SSM Parameter Store that stores the push token generated on the Darktrace Master instance.<br>  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),<br>  period (.), hyphen (-), and underscore (\_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.<br>  The push token is used to authenticate with the Darktrace Master instance. For more information, see the Darktrace Customer Portal (https://customerportal.darktrace.com/login).<br>  **Note**: for security reasons the push token should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform. | `string` | n/a | yes |
| <a name="input_ssh_cidrs"></a> [ssh\_cidrs](#input\_ssh\_cidrs) | (Optional) Allowed CIDR blocks for SSH (Secure Shell) access to vSensor. If not provided, the vSensors will not be accessible on port 22/tcp (ssh).<br>  An example when such access won't be required is when it is desired the vSensors to be accessible only via SSM session. | `list(any)` | `null` | no |
| <a name="input_ssh_keyname"></a> [ssh\_keyname](#input\_ssh\_keyname) | (Optional) Name of the ssh key pair stored in AWS. This key will be added to the vSensor ssh configuration. | `string` | `null` | no |
| <a name="input_ssm_session_enable"></a> [ssm\_session\_enable](#input\_ssm\_session\_enable) | Enable AWS System Manager Session Manager for the vSensors. Default is enable.<br>  When connecting via the AWS Systems Manager Session Manager it is recommended to use the session/preferences document created by the module.<br>  This will make sure that the session is encrypted and logged (in the same CloudWatch Log group as the vSensors logs).<br>  That is the same kms key that is used for encrypting log data in CloudWatch Logs.<br>  For the Systems Manager Session Manager allowed users you can<br>  [Enforce a session document permission check for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-sessiondocumentaccesscheck.html).<br>  The name of the session/preferences document is in the Outputs (`session_manager_preferences_name`).<br>  Example: `aws ssm start-session --target <instance_id> --document-name <session_manager_preferences_name>`. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for all resources (where possible). By default the module adds two tags to all resources (where possibe) with keys "deployment\_id" and "dt\_product".<br>  The value for the "deployment\_id" key is the `deployment_id` (see the Outputs for more details).<br>  The value for "dt\_product" is "vsensor". If you provide a tag with a key any of those it will overwrite the default. | `map(string)` | `{}` | no |
| <a name="input_traffic_mirror_target_rule_number"></a> [traffic\_mirror\_target\_rule\_number](#input\_traffic\_mirror\_target\_rule\_number) | Enter a priority to assign to the rule. | `number` | `100` | no |
| <a name="input_update_key"></a> [update\_key](#input\_update\_key) | Name of parameter that stores the Darktrace update key in the SSM Parameter Store.<br>  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),<br>  period (.), hyphen (-), and underscore (\_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.<br>  If you don't have Darktrace update key, you can obtain it from the Darktrace customer portal.<br>  **Note**: for security reasons the update key should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform. | `string` | n/a | yes |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR for the new VPC that will be created if `vpc_enable = true` | `string` | `"10.0.0.0/16"` | no |
| <a name="input_vpc_enable"></a> [vpc\_enable](#input\_vpc\_enable) | (Optional) If **true** a new VPC will be created with the provided `vpc_cidr`, `availability_zone`, `private_subnets_cidrs`,<br>  `public_subnets_cidrs` **regardless** of if the input variables for an existing VPC are also provided (i.e. `vpc_id` and `vpc_private_subnets`). | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | When Darktrace vSensor is deployed into an existing VPC this is the **VPC ID** of target deployment.<br>  Required if you are deploying the Darktrace vSensor into an existing VPC. | `string` | `null` | no |
| <a name="input_vpc_private_subnets"></a> [vpc\_private\_subnets](#input\_vpc\_private\_subnets) | When Darktrace vSensor is deployed into an existing VPC this is the list of the **Subnet IDs** that the vSensors should be launched into.<br>  You can specify at most one subnet per Availability Zone. Minimum one Subnet is required.<br>  Required if you are deploying the Darktrace vSensor into an existing VPC. | `list(any)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_vsensors_asg_name"></a> [autoscaling\_group\_vsensors\_asg\_name](#output\_autoscaling\_group\_vsensors\_asg\_name) | The name of the Auto Scaling Group. |
| <a name="output_deployment_id"></a> [deployment\_id](#output\_deployment\_id) | The unique deployment ID. This is a combination of the `deployment_prefix` (as prefix) followed by a hyphen (-) and an eleven character random string. |
| <a name="output_kms_key_vsensor_logs_arn"></a> [kms\_key\_vsensor\_logs\_arn](#output\_kms\_key\_vsensor\_logs\_arn) | If new kms key - the ARN of the kms key. |
| <a name="output_launch_template_vsensor_arn"></a> [launch\_template\_vsensor\_arn](#output\_launch\_template\_vsensor\_arn) | The ARN of the launch template (vSensors). |
| <a name="output_launch_template_vsensor_name"></a> [launch\_template\_vsensor\_name](#output\_launch\_template\_vsensor\_name) | The name of the launch template (vSensors). |
| <a name="output_nat_gw_eip_public_ip"></a> [nat\_gw\_eip\_public\_ip](#output\_nat\_gw\_eip\_public\_ip) | If `vpc_enable = true` - a list of the public IP addresses for the NAT gateways. |
| <a name="output_pcaps_s3_bucket_domain_name"></a> [pcaps\_s3\_bucket\_domain\_name](#output\_pcaps\_s3\_bucket\_domain\_name) | The s3 bucket's domain name. |
| <a name="output_pcaps_s3_bucket_name"></a> [pcaps\_s3\_bucket\_name](#output\_pcaps\_s3\_bucket\_name) | The name of the s3 bucket that stores the PCAPs. |
| <a name="output_private_subnets_id"></a> [private\_subnets\_id](#output\_private\_subnets\_id) | If `vpc_enable = true` - a list of the new private subnets. |
| <a name="output_public_subnets_id"></a> [public\_subnets\_id](#output\_public\_subnets\_id) | If `vpc_enable = true` - a list of the new public subnets. |
| <a name="output_session_manager_preferences_name"></a> [session\_manager\_preferences\_name](#output\_session\_manager\_preferences\_name) | The name of the SSM Session Manager document. |
| <a name="output_ssh_remote_access_ip"></a> [ssh\_remote\_access\_ip](#output\_ssh\_remote\_access\_ip) | If `bastion_enable=true` - The public IP address of the Bastion host (for the ssh remote access). |
| <a name="output_traffic_mirror_filter_arn"></a> [traffic\_mirror\_filter\_arn](#output\_traffic\_mirror\_filter\_arn) | The ARN of the traffic mirror filter. |
| <a name="output_traffic_mirror_filter_id"></a> [traffic\_mirror\_filter\_id](#output\_traffic\_mirror\_filter\_id) | The name of the traffic mirror filter. |
| <a name="output_traffic_mirror_target_arn"></a> [traffic\_mirror\_target\_arn](#output\_traffic\_mirror\_target\_arn) | The ARN of the traffic mirror target. |
| <a name="output_traffic_mirror_target_id"></a> [traffic\_mirror\_target\_id](#output\_traffic\_mirror\_target\_id) | The ID of the Traffic Mirror target. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The ID of the new VPC (if `vpc_enable = true`) |
| <a name="output_vsensor_cloudwatch_log_group_arn"></a> [vsensor\_cloudwatch\_log\_group\_arn](#output\_vsensor\_cloudwatch\_log\_group\_arn) | The ARN of the vSensor CloudWatch group. |
| <a name="output_vsensor_cloudwatch_log_group_name"></a> [vsensor\_cloudwatch\_log\_group\_name](#output\_vsensor\_cloudwatch\_log\_group\_name) | The name of the vSensor CloudWatch group. |
| <a name="output_vsensor_lb_arn"></a> [vsensor\_lb\_arn](#output\_vsensor\_lb\_arn) | The ARN of the Load Balancer. |
| <a name="output_vsensor_lb_arn_suffix"></a> [vsensor\_lb\_arn\_suffix](#output\_vsensor\_lb\_arn\_suffix) | The ARN suffix of the Load Balancer for use with CloudWatch Metrics. |
| <a name="output_vsensor_lb_dns_name"></a> [vsensor\_lb\_dns\_name](#output\_vsensor\_lb\_dns\_name) | The DNS name of the load balancer. Use this as the vSensorIP for connecting osSensors. |
| <a name="output_vsensor_lb_listener_arn"></a> [vsensor\_lb\_listener\_arn](#output\_vsensor\_lb\_listener\_arn) | A list of the ARNs of the LB listeners. |
| <a name="output_vsensor_lb_target_group_arn"></a> [vsensor\_lb\_target\_group\_arn](#output\_vsensor\_lb\_target\_group\_arn) | A list of the ARNs of the Target Groups. |
| <a name="output_vsensor_lb_target_group_arn_suffix"></a> [vsensor\_lb\_target\_group\_arn\_suffix](#output\_vsensor\_lb\_target\_group\_arn\_suffix) | A list of the ARN suffixes for use with CloudWatch Metrics. |
| <a name="output_vsensor_lb_target_group_name"></a> [vsensor\_lb\_target\_group\_name](#output\_vsensor\_lb\_target\_group\_name) | A list of the names of the Target Groups. |
| <a name="output_vsensors_autoscaling_security_group_arn"></a> [vsensors\_autoscaling\_security\_group\_arn](#output\_vsensors\_autoscaling\_security\_group\_arn) | The ARN of the security group for the vSensors. |
| <a name="output_vsensors_autoscaling_security_group_name"></a> [vsensors\_autoscaling\_security\_group\_name](#output\_vsensors\_autoscaling\_security\_group\_name) | The name of the security group for the vSensors. |

## Post deployment steps

### Configure networking

If you have a physical Darktrace deployment behind a firewall, you must grant access to the instance to the IP addresses of your NAT gateways. For a new VPC deployment, use the IP addresses in the `nat_gw_eip_public_ip` outputs. For an existing VPC deployment, use the IP addresses of the existing NAT gateways.

### Configure traffic mirroring

To add your existing EC2 instances to be mirrored and monitored, configure a traffic mirror session. For more information, see [Traffic mirror sessions](https://docs.aws.amazon.com/vpc/latest/mirroring/traffic-mirroring-session.html). When doing this, use the traffic mirror target and filter IDs in the outputs (`traffic_mirror_target_id`, `traffic_mirror_filter_id`). You can automate the process of adding your existing EC2 instances to this deployment. For more information, contact your Darktrace representative for scripts and guidance to do this, or visit [Darktrace Customer Portal](https://customerportal.darktrace.com/product-guides/main/aws-vpcmirror-mirror).

VPC Traffic Mirroring is only supported on AWS Nitro-based EC2 instance types and some non-Nitro instance types. For more information, see [Amazon VPC Traffic Mirroring is now supported on select non-Nitro instance types](https://aws.amazon.com/about-aws/whats-new/2021/02/amazon-vpc-traffic-mirroring-supported-select-non-nitro-instance-types).

To monitor EC2 instance types that do not support VPC Traffic Mirroring, configure them with Darktrace osSensors. When doing this, use the DNS name of the Network Load Balancer in the outputs - `vsensor_lb_dns_name`. For more information about configuring osSensors, visit the [Darktrace Customer Portal](https://customerportal.darktrace.com/login).

### Troubleshooting

In scenarios of invalid configuration parameters, upstream internet access blocked and other cases of the EC2 images failing to install and configure Darktrace vSensor, the Auto Scaling Group will fail to deploy.

Terraform will print a message with the specific error it encountered. Also, in most situations, logging will be available from the vSensor start up in CloudWatch. View "Log Groups", find the group named `<deployment_id>-vsensor-log-group` and look for Log Streams ending in `-userdata`.

If no `userdata` logging is provided in CloudWatch, you may need to connect directly to the vSensor via SSH or AWS Systems Manager and retrieve `/var/log/userdata.log` directly. You can consider to "Detach" the vSensor from the ASG to prevent it terminating during this procedure.

For situations where the error is not clear, contact Darktrace Customer Support via the [Darktrace Customer Portal](https://customerportal.darktrace.com), provide the terraform error and one of the above `userdata` logs if available.

### Configuration changes

A change in any of `instance_type`, `update_key`, `dt_push_token`, or `os_sensor_hmac_token` followed by `terraform apply` will result in replacing the vSensors.

In deployments where Cross-Zone Load Balancing is not enabled and a zone has a single vSensor, replacing the vSensor can cause minimal mirror packet loss from that Availability Zone while it is down. It is recommended to schedule Maintenance Window for such changes.

### Multiple Regions or Accounts

Each new deployment into a new region or AWS account should be given a new push token generated from the master instance UI config page. Each push token refers to a scalable set of vSensors, which share the same S3 storage bucket and config. When querying for pcap data, the master instance only queries one vSensor in the probe group (to avoid querying the same S3 bucket multiple times). If the same push token is reused in multiple environments, then querying for PCAP data will only search one of the environments and miss the rest.

For aggregating traffic mirrors from multiple AWS accounts, the vSensor can parse GENEVE traffic from an AWS Gateway Load Balancer. However if there are IP range overlaps between VPCs, it cannot currently identify separate VPCs.
