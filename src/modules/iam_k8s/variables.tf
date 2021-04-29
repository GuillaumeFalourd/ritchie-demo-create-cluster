
variable "kubernetes_cluster_name" {
  default = ""
  description = "The name of your kubernetes cluster"
}

variable "kubernetes_worker_iam_role_name" {
  default = ""
  description = "The name of the role attached to your k8s's workload runner nodes"
}
	