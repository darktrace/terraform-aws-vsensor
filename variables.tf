#Deployment configuration
variable "deployment_prefix" {
  type        = string
  description = "(Forces re-creating all resources) Two letter (lowercase) prefix that will be used to create a unique deployment ID to identify the resources."

  validation {
    condition     = length(var.deployment_prefix) == 2 && can(regex("^[a-z]+$", var.deployment_prefix))
    error_message = "The deployment_prefix must be two lowercase alphabet characters."
  }
}

variable "tags" {
  type        = map(string)
  description = <<EOT
  Tags for all resources (where possible). By default the module adds two tags to all resources (where possibe) with keys "deployment_id" and "dt_product".
  The value for the "deployment_id" key is the `deployment_id` (see the Outputs for more details).
  The value for "dt_product" is "vsensor". If you provide a tag with a key any of those it will overwrite the default.
  EOT
  default     = {}
}

#Darktrace environment configuration
variable "instance_host_name" {
  type        = string
  description = "Host name of the Darktrace Master instance."
}

variable "instance_port" {
  type        = number
  description = "Connection port between vSensor and the Darktrace Master instance."
  default     = 443
}

variable "push_token" {
  type        = string
  description = <<EOT
  Name of parameter in the SSM Parameter Store that stores the push token generated on the Darktrace Master instance.
  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),
  period (.), hyphen (-), and underscore (_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
  The push token is used to authenticate with the Darktrace Master instance. For more information, see the Darktrace Customer Portal (https://customerportal.darktrace.com/login).
  **Note**: for security reasons the push token should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform.
  EOT

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_/.]+$", var.push_token))
    error_message = <<EOT
    Invalid name - parameter names can consist of alphanumeric characters (0-9A-Za-z), period (.), hyphen (-), and underscore (_).
    In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
    https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html
    EOT
  }
}

#Darktrace vSensor configuration
variable "instance_type" {
  type        = string
  description = "Specify the EC2 instance type that will be used in the Auto-Scaling Group. It is recommended to start with `t3.medium`, change if you expect frequent high traffic."
  default     = "t3.medium"

  validation {
    condition     = contains(["t3.medium", "m5.large", "m6i.large", "m7i.large", "m5.xlarge", "m6i.xlarge", "m7i.xlarge", "m5.2xlarge", "m6i.2xlarge", "m6i.2xlarge", "m5.4xlarge", "m6i.4xlarge", "m7i.4xlarge"], var.instance_type)
    error_message = "The instance_type can be one of t3.medium, m5.large, m5.2xlarge, m5.4xlarge."
  }
}

variable "ssh_keyname" {
  type        = string
  description = "(Optional) Name of the ssh key pair stored in AWS. This key will be added to the vSensor ssh configuration."
  default     = null

  validation {
    condition     = var.ssh_keyname == null || var.ssh_keyname != ""
    error_message = "The ssh_keyname cannot be empty. If you don't want ssh key to be added to the vSensors then do not provide any value for this variable."
  }
}

variable "ssh_cidrs" {
  type        = list(any)
  description = <<EOT
  (Optional) Allowed CIDR blocks for SSH (Secure Shell) access to vSensor. If not provided, the vSensors will not be accessible on port 22/tcp (ssh).
  An example when such access won't be required is when it is desired the vSensors to be accessible only via SSM session.
  EOT
  default     = null
}

variable "update_key" {
  type        = string
  description = <<EOT
  Name of parameter that stores the Darktrace update key in the SSM Parameter Store.
  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),
  period (.), hyphen (-), and underscore (_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
  If you don't have Darktrace update key, you can obtain it from the Darktrace customer portal.
  **Note**: for security reasons the update key should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform.
  EOT

  validation {
    condition     = can(regex("^[a-zA-Z0-9-_/.]+$", var.update_key))
    error_message = <<EOT
    Invalid name - parameter names can consist of alphanumeric characters (0-9A-Za-z), period (.), hyphen (-), and underscore (_).
    In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
    https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html
    EOT
  }
}

variable "proxy" {
  type        = string
  description = <<EOT
  (Optional) A proxy if it is required for the vSensor to access the Darktrace Master instance.
  It should be specified in the format http://hostname:port with no authentication, or http://user:pass@hostname:port with authentication.
  EOT
  default     = ""

  validation {
    condition     = var.proxy == "" || can(regex("^http://.+:[0-9]+$", var.proxy)) || can(regex("^http://.+:.+@.+:[0-9]+$", var.proxy))
    error_message = "Invalid proxy - the proxy should be specified in the format http://hostname:port with no authentication, or http://user:pass@hostname:port with authentication."
  }
}

variable "desired_capacity" {
  type        = number
  description = "Desired number of vSensor instances in the Auto-Scaling group."
  default     = 2
}

variable "min_size" {
  type        = number
  description = <<EOT
  Minimum number of vSensor instances in the Auto-Scaling group. Recomended number is not to be less than the number of Availability Zone where the vSensors will be deployed into.
  EOT
  default     = 2
}

variable "max_size" {
  type        = number
  description = "Maximum number of vSensor instances in the Auto-Scaling group."
  default     = 5
}

variable "os_sensor_hmac_token" {
  type        = string
  description = <<EOT
  (Optional) Name of the SSM Parameter Store parameter that stores the hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor.
  The [parameter names](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) can consist of alphanumeric characters (0-9A-Za-z),
  period (.), hyphen (-), and underscore (_). In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
  **Note**: for security reasons the HMAC should be stored in SSM Parameter Store and the name of the parameter is passed to the installation script via terraform.
  EOT
  default     = ""

  validation {
    condition     = var.os_sensor_hmac_token == "" || can(regex("^[a-zA-Z0-9-_/.]+$", var.os_sensor_hmac_token))
    error_message = <<EOT
    Invalid name - parameter names can consist of alphanumeric characters (0-9A-Za-z), period (.), hyphen (-), and underscore (_).
    In addition, the slash forward character (/) is used to delineate hierarchies in parameter names.
    https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html
    EOT
  }
}

variable "ssm_session_enable" {
  type        = bool
  description = <<EOT
  Enable AWS System Manager Session Manager for the vSensors. Default is enable.
  When connecting via the AWS Systems Manager Session Manager it is recommended to use the session/preferences document created by the module.
  This will make sure that the session is encrypted and logged (in the same CloudWatch Log group as the vSensors logs).
  That is the same kms key that is used for encrypting log data in CloudWatch Logs.
  For the Systems Manager Session Manager allowed users you can
  [Enforce a session document permission check for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-sessiondocumentaccesscheck.html).
  The name of the session/preferences document is in the Outputs (`session_manager_preferences_name`).
  Example: `aws ssm start-session --target <instance_id> --document-name <session_manager_preferences_name>`.
  EOT

  default = true

  validation {
    condition     = contains([true, false], var.ssm_session_enable)
    error_message = "ssm_session_enable can be either true or false."
  }
}

#Load Balancing
variable "cross_zone_load_balancing_enable" {
  type        = bool
  description = <<EOT
  (Optional) Enable (true) or disable (false) cross-zone load balancing of the load balancer.
  If it is disabled, make sure there is **at least one** vSensor in each Availability Zone with Mirror sources.
  This will also configure the NLB 'Client routing policy' to `any availability zone` when `cross_zone_load_balancing_enable = true`,
  or to `availability zone affinity` when `cross_zone_load_balancing_enable = false`.
  For more information about cross-zone load balancing see the AWS documentation: [Network Load Balancers](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html#cross-zone-load-balancing),
  [Cross-zone load balancing for target groups](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/target-group-cross-zone.html),
  [Cross-zone load balancing](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/how-elastic-load-balancing-works.html#cross-zone-load-balancing),
  [Announcing new AWS Network Load Balancer (NLB) availability and performance capabilities](https://aws.amazon.com/about-aws/whats-new/2023/10/aws-nlb-availability-performance-capabilities/).
  Default is disable cross-zone load balancing.
  EOT
  default     = false

  validation {
    condition     = contains([true, false], var.cross_zone_load_balancing_enable)
    error_message = "cross_zone_load_balancing_enable can be either true or false."
  }
}

#Network configuration existing VPC
variable "vpc_id" {
  type        = string
  description = <<EOT
  When Darktrace vSensor is deployed into an existing VPC this is the **VPC ID** of target deployment.
  Required if you are deploying the Darktrace vSensor into an existing VPC.
  EOT
  default     = null
}

variable "vpc_private_subnets" {
  type        = list(any)
  description = <<EOT
  When Darktrace vSensor is deployed into an existing VPC this is the list of the **Subnet IDs** that the vSensors should be launched into.
  You can specify at most one subnet per Availability Zone. Minimum one Subnet is required.
  Required if you are deploying the Darktrace vSensor into an existing VPC.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for pri_sub_id in var.vpc_private_subnets :
      pri_sub_id == [] || pri_sub_id != [] && length(var.vpc_private_subnets) >= 1
    ])
    error_message = "Minimum one Subnet is required."

  }
}

#Network configuration new VPC
variable "vpc_enable" {
  type        = bool
  description = <<EOT
  (Optional) If **true** a new VPC will be created with the provided `vpc_cidr`, `availability_zone`, `private_subnets_cidrs`,
  `public_subnets_cidrs` **regardless** of if the input variables for an existing VPC are also provided (i.e. `vpc_id` and `vpc_private_subnets`).
  EOT
  default     = false
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the new VPC that will be created if `vpc_enable = true`"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[6-9]|2[0-8]))$", var.vpc_cidr))
    error_message = "The new VPC CIDR block  must be in the form x.x.x.x/16-28."
  }
}

variable "availability_zone" {
  type        = list(string)
  description = <<EOT
  If `vpc_enable = true` - Availability Zones that the vSensors, the NAT Gateways and all resources will be deployed into.
  EOT
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zone) >= 1
    error_message = "The number of availability zones must be at least one."
  }

}

variable "private_subnets_cidrs" {
  type        = list(string)
  description = <<EOT
  If `vpc_enable = true` - CIDRs for the private subnets that will be created for the vSensors.
  EOT
  default     = ["10.0.0.0/19", "10.0.32.0/19"]

  validation {
    condition     = length(var.private_subnets_cidrs) >= 1
    error_message = "The number of Private CIDR blocks must be at least one."
  }

  validation {
    condition = alltrue([
      for cidr in var.private_subnets_cidrs :
      can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-8]))$", cidr))
    ])
    error_message = "The Private CIDR blocks  must be in the form x.x.x.x/17-28."
  }

}

variable "public_subnets_cidrs" {
  type        = list(string)
  description = <<EOT
  If `vpc_enable = true` - CIDRs for the public subnets that will be created for the NAT Gateways.
  EOT
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.public_subnets_cidrs) >= 1
    error_message = "The number of Public CIDR blocks must be at least one."
  }

  validation {
    condition = alltrue([
      for cidr in var.public_subnets_cidrs :
      can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[7-9]|2[0-8]))$", cidr))
    ])
    error_message = "The Public CIDR blocks  must be in the form x.x.x.x/17-28."
  }
}

#VPC Traffic Mirror configuration
variable "traffic_mirror_target_rule_number" {
  description = "Enter a priority to assign to the rule."
  type        = number
  default     = 100
}

variable "filter_src_cidr_block" {
  description = "Source CIDR for the Traffic Mirror filter. Use the default `0.0.0.0/0` for all traffic."
  type        = string
  default     = "0.0.0.0/0"
}

variable "filter_dest_cidr_block" {
  description = "Destination CIDR for the Traffic Mirror filter. Use the default `0.0.0.0/0` for all traffic."
  type        = string
  default     = "0.0.0.0/0"
}

#Logs and captured packet retention
variable "lifecycle_pcaps_s3_bucket" {
  description = "Number of days to retain captured packets in Amazon S3. Longer retention will increase storage costs. Set to 0 to disable PCAP storage."
  type        = number
  default     = 7

  validation {
    condition     = floor(var.lifecycle_pcaps_s3_bucket) == var.lifecycle_pcaps_s3_bucket && var.lifecycle_pcaps_s3_bucket >= 0
    error_message = "The number of days to retain captured packets in Amazon S3 must be a whole number."
  }
}

#Bastion
variable "bastion_enable" {
  type        = bool
  description = <<EOT
  If `true` will create a public Bastion.
  (Optional; applicable only if `vpc_enable = true`) If **true** a standalone/single bastion host will be installed to provide ssh remote access to the vSensors.
  It will be installed in the first Public subnet CIDR (`public_subnets_cidrs`). The bastion will automatically have ssh access to the vSensors.
  EOT
  default     = false
}

variable "bastion_instance_type" {
  description = "(Optional) The ec2 instance type for the bastion host. This can be one of t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.bastion_instance_type)
    error_message = "The instance_type can be one of t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge."
  }
}

variable "bastion_ssh_keyname" {
  description = <<EOT
  (Optional) Name of the ssh key pair stored in AWS. This key will be added to the vSensor ssh configuration.
  Use case to not provide ssh key pair name - when it is desirable the access to vSensors to be via AWS System Manager Session only (see ssm_session_enable).
  EOT
  type        = string
  default     = null
}

variable "bastion_ssh_cidrs" {
  description = "(Optional) Allowed CIDR blocks for SSH (Secure Shell) access to the bastion host."
  type        = list(any)
  default     = []
}

variable "bastion_ami" {
  description = <<EOT
  (Optional) The AMI operating system for the bastion host. This can be one of Amazon-Linux2-HVM, Ubuntu-Server-20_04-LTS-HVM.
  Default user names: for Amazon-Linux2-HVM the user name is `ec2-user`, for Ubuntu-Server-20_04-LTS-HVM the user name is `ubuntu`.
  EOT
  type        = string
  default     = "Amazon-Linux2-HVM"

  validation {
    condition     = contains(["Amazon-Linux2-HVM", "Ubuntu-Server-20_04-LTS-HVM"], var.bastion_ami)
    error_message = "The instance_type can be one of Amazon-Linux2-HVM, Ubuntu-Server-20_04-LTS-HVM."
  }
}

variable "cloudwatch_logs_days" {
  description = <<EOT
  Number of days to retain vSensor CloudWatch logs. 
  Allowed values are 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653, and 0.
  If you select 0, the events in the log group are always retained and never expire.
  EOT
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs_days)
    error_message = "Allowed values for cloudwatch_logs_days are 0, 1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "cw_log_group_name" {
  description = <<EOT
  (Optional) CloudWatch Log Group name for the vSensor logs.
  [Naming restrictions](https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html#description) apply.
  If not provided the deployment ID (`deployment_id`) will be used.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.cw_log_group_name == "" || can(regex("^[a-zA-Z0-9-_/:#.]{1,512}$", var.cw_log_group_name))
    error_message = <<EOT
    The cw_log_group_name can be between 1 and 512 characters long.
    Possible characters are: a-z, A-Z, 0-9, '_' (underscore), '-' (hyphen), '/' (forward slash), '.' (period), and '#' (number sign).
    https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html#description
    EOT
  }
}

variable "cw_namespace" {
  description = <<EOT
  (Optional) CloudWatch Metrics Namespace for the vSensors (if `cw_metrics_enable = true`), for example vSensorMetrics.
  [Naming restrictions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html) apply.
  If not provided the deployment ID (`deployment_id`) will be used.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = var.cw_namespace == "" || can(regex("^[a-zA-Z0-9-_/:#.]{1,255}$", var.cw_namespace))
    error_message = <<EOT
    The cw_namespace  must contain valid ASCII characters, and be 255 or fewer characters.
    Possible characters are: alphanumeric characters (0-9A-Za-z), period (.), hyphen (-), underscore (_), forward slash (/), hash (#), and colon (:).
    A namespace must contain at least one non-whitespace character.
    https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html
    EOT
  }
}

variable "cw_metrics_enable" {
  type        = bool
  description = "(Optional) If true (default) a Custom Namespace for vSensor CloudWatch Metrics will be created."
  default     = true

  validation {
    condition     = contains([true, false], var.cw_metrics_enable)
    error_message = "cw_metrics_enable can be either true or false."
  }
}

variable "kms_key_enable" {
  type        = bool
  description = "If true (default) the module will create a new kms key for encrypting log data in CloudWatch Logs. If false, `kms_key_arn` should be provided."
  default     = true

  validation {
    condition     = contains([true, false], var.kms_key_enable)
    error_message = "kms_key_enable can be either true or false."
  }
}

variable "kms_key_arn" {
  type        = string
  description = <<EOT
  ARN of the kms key for encrypting log data in CloudWatch Logs. This is when the kms key is created outside the module.
  The key policy should allow log encryption see [AWS documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html).
  If `kms_key_enable` is true then this kms key arn will be ignored.
  EOT
  default     = null
}

variable "kms_key_rotation" {
  type        = bool
  description = "Specifies whether key rotation is enabled. Defaults to false."
  default     = false

  validation {
    condition     = contains([true, false], var.kms_key_rotation)
    error_message = "kms_key_rotation can be either true or false."
  }
}
