resource "aws_s3_bucket" "vsensor_pcaps_s3" {
  bucket_prefix = join("", [local.deployment_id, "-vsensor-pcaps-"])

  force_destroy = true

  tags = local.all_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vsensor_pcaps_s3" {
  bucket = aws_s3_bucket.vsensor_pcaps_s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vsensor_pcaps_s3" {
  bucket = aws_s3_bucket.vsensor_pcaps_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "vsensor_pcaps_s3" {
  bucket = aws_s3_bucket.vsensor_pcaps_s3.id

  rule {
    id = "delete-after-${var.lifecycle_pcaps_s3_bucket}-days"

    expiration {
      days = var.lifecycle_pcaps_s3_bucket
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "vsensor_pcaps_s3" {
  bucket = aws_s3_bucket.vsensor_pcaps_s3.id
  policy = data.aws_iam_policy_document.vsensor_pcaps_s3.json
}

data "aws_iam_policy_document" "vsensor_pcaps_s3" {
  statement {
    sid    = "PCAPSSSLOnlyPolicy"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.vsensor_pcaps_s3.arn,
      "${aws_s3_bucket.vsensor_pcaps_s3.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"

      values = [
        "false",
      ]
    }
  }
}

resource "aws_s3_bucket_logging" "vsensor_pcaps_s3" {
  bucket = aws_s3_bucket.vsensor_pcaps_s3.id

  target_bucket = aws_s3_bucket.vsensor_pcaps_s3.id
  target_prefix = "s3logging/"
}
