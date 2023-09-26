resource "aws_ssm_document" "session_manager_preferences" {
  count = var.ssm_session_enable ? 1 : 0

  name            = "${local.deployment_id}-vsensors-session-manager-prefs"
  document_type   = "Session"
  document_format = "JSON"

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document for Session Manager for vSensor deployment"
    sessionType   = "Standard_Stream"
    inputs = {
      s3BucketName                = ""
      s3KeyPrefix                 = ""
      s3EncryptionEnabled         = true
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.vsensor_log_group.name
      cloudWatchEncryptionEnabled = true
      idleSessionTimeout          = "20"
      maxSessionDuration          = ""
      cloudWatchStreamingEnabled  = true
      kmsKeyId                    = local.kms_key_arn
      runAsEnabled                = false
      runAsDefaultUser            = ""
      shellProfile = {
        linux   = "TOKEN=`curl -X PUT \"http://169.254.169.254/latest/api/token\" -H \"X-aws-ec2-metadata-token-ttl-seconds: 120\" -s`\nINSTANCE_ID=`curl -H \"X-aws-ec2-metadata-token: $TOKEN\" http://169.254.169.254/latest/meta-data/instance-id -s`\nDATE=`date --iso-8601='ns'`\necho \"\"\necho \"\"; echo \"#######################################################\"; echo \"#                                                     #\"; echo \"# Session start: $DATE  #\"; echo \"#                                                     #\"; echo \"# Instance ID:  $INSTANCE_ID                   #\"; echo \"#                                                     #\";  echo \"#######################################################\"\necho \"\""
        windows = ""
      }
    }
  })
}
