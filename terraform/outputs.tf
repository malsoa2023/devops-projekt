output "public_ip" {
  description = "Publiczny adres IP serwera"
  value       = aws_eip.app.public_ip
}

output "app_url" {
  description = "Adres aplikacji"
  value       = "http://${aws_eip.app.public_ip}"
}

output "grafana_url" {
  description = "Adres Grafany"
  value       = "http://${aws_eip.app.public_ip}/grafana/"
}

output "tls_domain" {
  description = "Darmowa domena wskazująca na serwer (do włączenia HTTPS przez SITE_ADDRESS)"
  value       = "${replace(aws_eip.app.public_ip, ".", "-")}.sslip.io"
}
