# Future Improvements Backlog

This document tracks potential enhancements for the Rocket.Chat on MicroK8s deployment. Each item includes a short outcome and first steps.

## 1) CI/CD (GitHub Actions)
- Outcome: One-click lint, template check, and Helm upgrade.
- Steps:
  - Add workflows: chart lint (ct), kubeconform, helm upgrade --install to the VM via SSH.
  - Gate on PR approvals; use environments for prod.

## 2) Backups & DR
- Outcome: Recover MongoDB and configs within RTO/RPO targets.
- Steps:
  - Nightly mongodump to encrypted storage; weekly restore test.
  - Snapshot PVs (Premium SSD) and keep 7–14 days.
  - Back up `values-production.yaml`, `clusterissuer.yaml`, TLS secrets.

## 3) Alerting & SLOs
- Outcome: Proactive alerts on health and capacity.
- Steps:
  - Alertmanager rules: CPU>80%, mem>80%, pod down, Mongo connection errors, cert expiry.
  - Grafana dashboards for Rocket.Chat and MongoDB.

## 4) Secrets Management
- Outcome: No secrets in Git; auditable rotation.
- Steps:
  - Move sensitive values to Kubernetes Secrets; reference in values via `extraEnvFrom`.
  - Optionally adopt SOPs/age for Git-encrypted secrets.

## 5) IaC (Terraform for Azure)
- Outcome: Reproducible VM, disk, NSG, DNS, and bootstrap.
- Steps:
  - Terraform modules for VM (D4ads_v5), Premium SSD data disk, NSG (80/443), DNS A records.
  - Provisioning script to clone repo and run setup/deploy.

## 6) AKS Migration (HA)
- Outcome: Managed Kubernetes with multiple nodes.
- Steps:
  - AKS cluster (2–3 nodes), NGINX Ingress Controller, cert-manager, external DNS.
  - External MongoDB (Atlas/Cosmos) or AKS StatefulSet with replica set.

## 7) Cost Controls
- Outcome: Predictable spend.
- Steps:
  - Auto-shutdown schedule, reserved instance/Savings Plan.
  - Tune Prometheus retention and scrape intervals.

## 8) SSO & Security Hardening
- Outcome: Central auth and reduced risk.
- Steps:
  - Configure OAuth/SAML; enforce strong admin creds and MFA.
  - Regularly rotate TLS/email in `clusterissuer.yaml`.

## References
- Rocket.Chat Kubernetes deploy: https://docs.rocket.chat/docs/deploy-with-kubernetes
- Rocket.Chat Helm chart: https://github.com/RocketChat/helm-charts/tree/master/rocketchat
