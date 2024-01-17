#Deployment configuration
variable "deployment_prefix" {
  type        = string
  description = "Two lowercase alphabet characters that will be used to create deployment ID and resource names."
  default     = ""

  validation {
    condition     = length(var.deployment_prefix) == 2 && can(regex("^[a-z]+$", var.deployment_prefix))
    error_message = "The deployment_prefix must be two lowercase alphabet characters."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for all resources."
  default     = {}
}

#Darktrace environment configuration
variable "instance_host_name" {
  type        = string
  description = "Host name of the Darktrace Master instance."
  default     = null
}

variable "instance_port" {
  type        = number
  description = "Connection port between vSensor and the Darktrace Master instance."
  default     = 443
}

variable "push_token" {
  type        = string
  description = <<EOT
  Name of parameter in the SSM Parameter Store that stores the push token. 
  The push token is used to authenticate with the Darktrace Master instance.
  For more information, see the Darktrace Customer Portal (https://customerportal.darktrace.com/login)."
  EOT
  default     = ""

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
  description = "EC2 instance type."
  default     = "t3.medium"

  validation {
    condition     = contains(["t3.medium", "m5.large", "m5.2xlarge", "m5.4xlarge"], var.instance_type)
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
  description = "Allowed CIDR blocks for SSH (Secure Shell) access to vSensor."
  default     = null
}

variable "update_key" {
  type        = string
  description = "Name of parameter that stores the Darktrace update key in the SSM Parameter Store. If you don't have one, contact your Darktrace representative."
  default     = ""

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
  description = "(Optional) A proxy that should be specified in the format http://user:pass@hostname:port."
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
  Minimum number of vSensor instances in the Auto-Scaling group. 
  Recomended number is not to be less than the number of Availability Zone where the vSensors will be deployed into.
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
  description = "Name of the SSM Parameter Store parameter that stores the hash-based message authentication code (HMAC) token to authenticate osSensors with vSensor."
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
  Enable or disable AWS System Manager Session Manager for the vSensors. Default is enable.
  When connecting via the AWS Systems Manager Session Manager it is recommended to use the session/preferences document created by the module.
  This will make sure that the session is encrypted and logged (in the same CloudWatch Log group as the vSensors logs).
  That is the same kms key that is used for encrypting log data in CloudWatch Logs.
  For the Systems Manager Session Manager allowed users you can [Enforce a session document permission check for the AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-sessiondocumentaccesscheck.html).
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
  description = "Enable or disable (default) cross-zone load balancing."
  default     = false

  validation {
    condition     = contains([true, false], var.cross_zone_load_balancing_enable)
    error_message = "cross_zone_load_balancing_enable can be either true or false."
  }
}

#Network configuration existing VPC
variable "vpc_id" {
  type        = string
  description = "VPC ID of target deployment."
  default     = null
}

variable "vpc_private_subnets" {
  type        = list(any)
  description = "List of the Subnet IDs that the vSensors should be launched into. You can specify at most one subnet per Availability Zone. Minimum two Subnets are required."
  default     = []

  validation {
    condition = alltrue([
      for pri_sub_id in var.vpc_private_subnets :
      pri_sub_id == [] || pri_sub_id != [] && length(var.vpc_private_subnets) >= 2
    ])
    error_message = "Minimum two Subnets are required."

  }
}

#Network configuration new VPC
variable "vpc_enable" {
  type        = bool
  description = "If `true` will create a new VPC."
  default     = false
}

variable "vpc_cidr" {
  type        = string
  description = "The IPv4 CIDR blobk for the VPC. Default 10.0.0.0/16."
  default     = "10.0.0.0/16"

  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]).){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(/(1[6-9]|2[0-8]))$", var.vpc_cidr))
    error_message = "The new VPC CIDR block  must be in the form x.x.x.x/16-28."
  }
}

variable "availability_zone" {
  type        = list(string)
  description = "Availability Zones to deploy the vSensors. At least two availablity zones are required."
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zone) >= 2
    error_message = "The number of availability zones must be at least two."
  }

}

variable "private_subnets_cidrs" {
  type        = list(string)
  description = "Private CIDR blocks  to deploy the vSensors. Default 10.0.0.0/19, 10.0.32.0/19."
  default     = ["10.0.0.0/19", "10.0.32.0/19"]

  validation {
    condition     = length(var.private_subnets_cidrs) >= 2
    error_message = "The number of Private CIDR blocks must be at least two."
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
  description = "Public CIDR block to deploy the NAT Gateways. Default 10.0.128.0/20, 10.0.144.0/20."
  default     = ["10.0.128.0/20", "10.0.144.0/20"]

  validation {
    condition     = length(var.public_subnets_cidrs) >= 2
    error_message = "The number of Public CIDR blocks must be at least two."
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
  description = "If `true` will create a public Bastion."
  default     = false
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the Bastion."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small", "t3.medium", "t3.large", "t3.xlarge", "t3.2xlarge"], var.bastion_instance_type)
    error_message = "The instance_type can be one of t3.micro, t3.small, t3.medium, t3.large, t3.xlarge, t3.2xlarge."
  }
}

variable "bastion_ssh_keyname" {
  description = "Name of the ssh key pair stored in AWS. This key will be added to the Bastion ssh configuration."
  type        = string
  default     = null
}

variable "bastion_ssh_cidrs" {
  description = "Allowed CIDR block for SSH (Secure Shell) access to the Bastion."
  type        = list(any)
  default     = []
}

variable "bastion_ami" {
  description = "Linux distribution for the Amazon Machine Image (AMI) used for the bastion host instances."
  type        = string
  default     = "Amazon-Linux2-HVM"

  validation {
    condition     = contains(["Amazon-Linux2-HVM", "Ubuntu-Server-20_04-LTS-HVM"], var.bastion_ami)
    error_message = "The instance_type can be one of Amazon-Linux2-HVM, Ubuntu-Server-20_04-LTS-HVM."
  }
}

variable "cloudwatch_logs_days" {
  description = "Number of days to retain Cloudwatch logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.cloudwatch_logs_days)
    error_message = "Allowed values for cloudwatch_logs_days are 0, 1,3,5,7,14,30,60,90,120,150,180,365,400,545,731,1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "cw_log_group_name" {
  description = "CloudWatch Log Group name for the vSensor logs. The default is to use the deployment ID (deployment_id). Details regarding deployment_id can be found in the README."
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
  description = "CloudWatch metrics Namespace for the vSensors, for example vSensorMetrics. If not provided the deployment ID (deployment_id) will be used. Details regarding deployment_id can be found in the README."
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
  description = "Enable (true) or disable vSensor CloudWatch Metrics Custom namespace."
  default     = true

  validation {
    condition     = contains([true, false], var.cw_metrics_enable)
    error_message = "cw_metrics_enable can be either true or false."
  }
}

variable "kms_key_enable" {
  type        = bool
  description = "If true (default) the module will create a new kms key for encrypting log data in CloudWatch Logs. If false, kms_key_arn should be provided."
  default     = true

  validation {
    condition     = contains([true, false], var.kms_key_enable)
    error_message = "kms_key_enable can be either true or false."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the kms key for encrypting log data in CloudWatch Logs. If kms_key_enable is true then this kms key arn will be ignored."
  default     = null
}

variable "kms_key_rotation" {
  type        = bool
  description = "Specifies whether key rotation is enabled. Defaults to false."
  default     = false

  validation {
    condition     = contains([true, false], var.kms_key_rotation)
    error_message = "cw_metrics_enable can be either true or false."
  }
}
