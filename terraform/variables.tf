variable "project_name" {
  description = "Nazwa projektu, używana w nazwach i tagach zasobów"
  type        = string
  default     = "devops-projekt"
}

variable "region" {
  description = "Region AWS (Frankfurt - najbliżej Polski)"
  type        = string
  default     = "eu-central-1"
}

variable "instance_type" {
  description = "Typ instancji EC2 (t3.micro mieści się w darmowym pakiecie AWS)"
  type        = string
  default     = "t3.micro"
}

variable "root_volume_size" {
  description = "Rozmiar dysku w GB (darmowy pakiet obejmuje do 30 GB)"
  type        = number
  default     = 20
}

variable "ssh_public_key_path" {
  description = "Ścieżka do klucza publicznego SSH, którym logujemy się na serwer"
  type        = string
  default     = "~/.ssh/devops_projekt.pub"
}

variable "ssh_allowed_cidr" {
  description = "Adresy, z których dozwolony jest SSH. Domyślnie wszystkie, bo GitHub Actions łączy się z różnych adresów (logowanie tylko kluczem)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "budget_email" {
  description = "E-mail na alert budżetowy AWS (puste = bez budżetu)"
  type        = string
  default     = ""
}

variable "budget_limit_usd" {
  description = "Próg budżetu w USD, po którego przekroczeniu przychodzi e-mail"
  type        = number
  default     = 1
}
