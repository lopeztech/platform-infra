output "bucket_names" {
  description = "Map of layer → bucket name"
  value = {
    for layer, bucket in google_storage_bucket.medallion :
    layer => bucket.name
  }
}
