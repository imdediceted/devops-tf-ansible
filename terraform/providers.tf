terraform {
  required_version = ">= 1.6"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.150"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "yandex" {
  zone                     = var.yc_zone
  cloud_id                 = "b1govv63o953g8epnhij"
  folder_id                = "b1glf9ip3q3al2sebg0p"
  service_account_key_file = pathexpand("~/yc-sa-key.json")
  # (cloud_id/folder_id можно оставить через переменные окружения YC_CLOUD_ID / YC_FOLDER_ID)
}
