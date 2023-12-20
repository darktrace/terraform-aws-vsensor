resource "aws_s3_bucket" "vsensor_pcaps_s3" {
  count = local.s3_count

  bucket_prefix = join("", [local.deployment_id, "-vsensor-pcaps-"])

  force_destroy = true

  tags = local.all_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vsensor_pcaps_s3" {
  count = local.s3_count

  bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vsensor_pcaps_s3" {
  count = local.s3_count

  bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "vsensor_pcaps_s3" {
  count = local.s3_count

  bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id

  rule {
    id = "delete-after-${var.lifecycle_pcaps_s3_bucket}-days"

    expiration {
      days = var.lifecycle_pcaps_s3_bucket
    }

    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "vsensor_pcaps_s3" {
  count = local.s3_count

  bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id
  policy = data.aws_iam_policy_document.vsensor_pcaps_s3[0].json
}

data "aws_iam_policy_document" "vsensor_pcaps_s3" {
  count = local.s3_count

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
      aws_s3_bucket.vsensor_pcaps_s3[0].arn,
      "${aws_s3_bucket.vsensor_pcaps_s3[0].arn}/*",
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
  count = local.s3_count

  bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id

  target_bucket = aws_s3_bucket.vsensor_pcaps_s3[0].id
  target_prefix = "s3logging/"
}
