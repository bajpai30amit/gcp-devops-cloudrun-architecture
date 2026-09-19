terraform {
  backend "gcs" {
    bucket = "watchful-idea-505906-u3-tfstate"
    prefix = "dev"
  }
}