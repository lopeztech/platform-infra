# Remove the old SPA bucket from Terraform state without destroying it.
# The bucket contents can be cleaned up manually afterwards:
#   gsutil rm -r gs://sre-monitor-lcd-sre-monitor-prod
removed {
  from = google_storage_bucket.app

  lifecycle {
    destroy = false
  }
}

removed {
  from = google_storage_bucket_iam_member.public_read

  lifecycle {
    destroy = false
  }
}
