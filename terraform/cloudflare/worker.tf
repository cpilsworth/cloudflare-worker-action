provider "cloudflare" {
  version = "~> 1.9"
  email = "${var.cloudflare_email}"
  token = "${var.cloudflare_token}"
}

resource "cloudflare_worker_script" "worker" {
  zone    = "${var.zone}"
  content = "${file("${var.worker_js}")}"
}
