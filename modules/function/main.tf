locals {
  timestamp = formatdate("YYMMDDhhmmss", timestamp())
}

# Compress source code
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "modules/function/cf"
  output_path = "/tmp/function-${local.timestamp}.zip"
}

# Create bucket that will host the source code
resource "google_storage_bucket" "bucket" {
  project = var.project
  name = "${var.project}-function"
}

# Add source code zip to bucket
resource "google_storage_bucket_object" "zip" {
  # Append file MD5 to force bucket to be recreated
  name   = "source.zip#${data.archive_file.source.output_md5}"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.source.output_path
}

# Enable Cloud Functions API
resource "google_project_service" "cf" {
  project = var.project
  service = "cloudfunctions.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Enable Cloud Build API
resource "google_project_service" "cb" {
  project = var.project
  service = "cloudbuild.googleapis.com"

  disable_dependent_services = true
  disable_on_destroy         = false
}

# Create Cloud Function
resource "google_cloudfunctions_function" "function" {
  name    = var.name
  project = var.project
  runtime = "nodejs12"
  region = var.region

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  trigger_http          = true
  entry_point           = var.entry_point
}

# Create IAM entry so all users can invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = var.project
  region         = var.region
  cloud_function = google_cloudfunctions_function.function.name
  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}