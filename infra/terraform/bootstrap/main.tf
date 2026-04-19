resource "google_storage_bucket" "tf_state" {
  name                        = var.tf_state_bucket
  location                    = var.tf_state_location
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy

  versioning {
    enabled = true
  }

  dynamic "lifecycle_rule" {
    for_each = var.delete_old_versions ? [1] : []
    content {
      action {
        type = "Delete"
      }

      condition {
        age                = var.noncurrent_version_age_days
        with_state         = "ARCHIVED"
        num_newer_versions = 3
      }
    }
  }
}
