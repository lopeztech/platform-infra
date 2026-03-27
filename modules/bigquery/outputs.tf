output "dataset_ids" {
  value = {
    for name, dataset in google_bigquery_dataset.pipeline :
    name => dataset.dataset_id
  }
}
