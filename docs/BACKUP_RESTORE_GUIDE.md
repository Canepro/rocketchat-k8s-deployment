# 💾 Backup & Restore Guide

## Overview

This guide provides comprehensive procedures for backing up and restoring the Rocket.Chat AKS deployment, including MongoDB data, PVC snapshots, cluster state, and secrets management.

## 🎯 Backup Strategy

### Multi-Layer Backup Approach

1. **MongoDB Data Backups**: Daily `mongodump` to Azure Blob Storage
2. **PVC Snapshots**: Azure Disk Snapshots for persistent volumes
3. **Cluster State**: Kubernetes manifests, secrets, and configurations
4. **Secrets Management**: Azure Key Vault integration
5. **Infrastructure State**: Terraform state preservation

## 📁 Backup Scripts Overview

```
scripts/backup/
├── mongodb-backup.sh           # MongoDB data backup
├── mongodb-restore.sh          # MongoDB data restoration
├── create-pvc-snapshots.sh     # PVC snapshot creation
├── restore-from-snapshots.sh   # PVC restoration
├── backup-cluster-state.sh     # Cluster state backup
├── backup-validation.sh        # Backup integrity checks
└── backup-integrity-check.sh   # Comprehensive validation
```

## 🗄️ MongoDB Backup & Restore

### MongoDB Backup Process

**Script**: `scripts/backup/mongodb-backup.sh`

**Features**:
- Automated `mongodump` with authentication
- Compression and encryption
- Azure Blob Storage upload
- Encryption key storage in Azure Key Vault
- Backup validation and integrity checks
- Retention policy management

**Usage**:
```bash
# Manual backup
./scripts/backup/mongodb-backup.sh

# Automated backup (via pipeline)
# Triggered daily by Azure DevOps pipeline
```

**Backup Process**:
1. **Authentication**: Connect to MongoDB with credentials
2. **Data Export**: Perform `mongodump` with compression
3. **Encryption**: Encrypt backup with generated key
4. **Upload**: Upload to Azure Blob Storage
5. **Key Storage**: Store encryption key in Azure Key Vault
6. **Validation**: Verify backup integrity
7. **Cleanup**: Remove old backups based on retention policy

### MongoDB Restore Process

**Script**: `scripts/backup/mongodb-restore.sh`

**Features**:
- Download from Azure Blob Storage
- Decryption using stored keys
- Data restoration with validation
- Rollback capabilities

**Usage**:
```bash
# Restore from latest backup
./scripts/backup/mongodb-restore.sh

# Restore from specific timestamp
./scripts/backup/mongodb-restore.sh --timestamp 20241201_120000
```

**Restore Process**:
1. **Key Retrieval**: Get encryption key from Azure Key Vault
2. **Download**: Download backup from Azure Blob Storage
3. **Decryption**: Decrypt backup using stored key
4. **Data Import**: Perform `mongorestore` with validation
5. **Verification**: Verify data integrity and completeness

## 💿 PVC Snapshots

### PVC Snapshot Creation

**Script**: `scripts/backup/create-pvc-snapshots.sh`

**Features**:
- Azure Disk Snapshots for all PVCs
- Timestamp tagging
- Retention policy (7 days)
- Snapshot validation

**Usage**:
```bash
# Create snapshots for all PVCs
./scripts/backup/create-pvc-snapshots.sh

# Create snapshots with custom retention
./scripts/backup/create-pvc-snapshots.sh --retention-days 14
```

**Snapshot Process**:
1. **PVC Discovery**: Identify all PVCs in the cluster
2. **Snapshot Creation**: Create Azure Disk Snapshots
3. **Tagging**: Tag snapshots with timestamp and metadata
4. **Validation**: Verify snapshot creation
5. **Cleanup**: Remove old snapshots based on retention policy

### PVC Restoration

**Script**: `scripts/backup/restore-from-snapshots.sh`

**Features**:
- Restore PVCs from snapshots
- Data integrity validation
- Rollback capabilities

**Usage**:
```bash
# Restore from latest snapshots
./scripts/backup/restore-from-snapshots.sh

# Restore from specific timestamp
./scripts/backup/restore-from-snapshots.sh --timestamp 20241201_120000
```

**Restore Process**:
1. **Snapshot Selection**: Choose appropriate snapshots
2. **PVC Recreation**: Create new PVCs from snapshots
3. **Data Validation**: Verify data integrity
4. **Application Restart**: Restart applications to use restored data

## 🏗️ Cluster State Backup

### Cluster State Backup

**Script**: `scripts/backup/backup-cluster-state.sh`

**Features**:
- Helm values and chart versions
- Kubernetes secrets (encrypted)
- ConfigMaps and ingress definitions
- Certificate states
- Azure Blob Storage upload

**Usage**:
```bash
# Backup cluster state
./scripts/backup/backup-cluster-state.sh

# Backup with custom naming
./scripts/backup/backup-cluster-state.sh --name custom-backup
```

**Backup Process**:
1. **Helm State**: Export Helm releases and values
2. **Kubernetes Resources**: Export ConfigMaps, Secrets, Ingress
3. **Certificates**: Backup certificate states
4. **Compression**: Compress and encrypt backup
5. **Upload**: Upload to Azure Blob Storage
6. **Validation**: Verify backup integrity

## 🔐 Secrets Management

### Secrets Backup

**Script**: `scripts/secrets/backup-secrets-to-keyvault.sh`

**Features**:
- Backup Kubernetes secrets to Azure Key Vault
- Encryption and secure storage
- Automated synchronization

**Usage**:
```bash
# Backup secrets to Key Vault
./scripts/secrets/backup-secrets-to-keyvault.sh

# Backup specific namespace
./scripts/secrets/backup-secrets-to-keyvault.sh --namespace rocketchat
```

### Secrets Restoration

**Script**: `scripts/secrets/sync-from-keyvault.sh`

**Features**:
- Restore secrets from Azure Key Vault
- Automated secret injection
- Validation and verification

**Usage**:
```bash
# Sync secrets from Key Vault
./scripts/secrets/sync-from-keyvault.sh

# Sync specific secrets
./scripts/secrets/sync-from-keyvault.sh --secret mongodb-password
```

## ✅ Backup Validation

### Integrity Checks

**Script**: `scripts/backup/backup-validation.sh`

**Features**:
- MongoDB backup integrity verification
- PVC snapshot validation
- Cluster state backup verification
- Comprehensive reporting

**Usage**:
```bash
# Validate all backups
./scripts/backup/backup-validation.sh

# Validate specific backup type
./scripts/backup/backup-validation.sh --type mongodb
```

### Comprehensive Validation

**Script**: `scripts/backup/backup-integrity-check.sh`

**Features**:
- End-to-end backup validation
- Data integrity verification
- Recovery testing
- Performance metrics

**Usage**:
```bash
# Comprehensive integrity check
./scripts/backup/backup-integrity-check.sh

# Check specific components
./scripts/backup/backup-integrity-check.sh --component mongodb
```

## 🔄 Automated Backup Pipeline

### Azure DevOps Pipeline

**Pipeline**: `azure-pipelines/backup-automation.yml`

**Features**:
- Daily automated backups
- MongoDB data backup
- PVC snapshot creation
- Backup validation
- Notification system

**Triggers**:
- **Scheduled**: Daily at 2:00 AM UTC
- **Manual**: On-demand backup execution
- **Event-driven**: Cost threshold alerts

### Pipeline Stages

1. **MongoDB Backup Stage**
   - Execute `mongodb-backup.sh`
   - Validate backup integrity
   - Upload to Azure Blob Storage

2. **PVC Snapshot Stage**
   - Execute `create-pvc-snapshots.sh`
   - Validate snapshot creation
   - Tag and organize snapshots

3. **Cluster State Backup Stage**
   - Execute `backup-cluster-state.sh`
   - Export cluster configuration
   - Upload to Azure Blob Storage

4. **Validation Stage**
   - Execute `backup-validation.sh`
   - Verify all backups
   - Generate validation report

5. **Notification Stage**
   - Send success/failure notifications
   - Update monitoring dashboards
   - Alert on backup failures

## 🚨 Emergency Recovery

### Emergency Restore Process

**Scenario**: Complete cluster failure or data loss

**Steps**:
1. **Assessment**: Evaluate the extent of data loss
2. **Backup Selection**: Choose appropriate backup/snapshot
3. **Infrastructure Recreation**: Use Terraform to recreate cluster
4. **Data Restoration**: Restore from backups/snapshots
5. **Validation**: Verify system functionality
6. **Monitoring**: Ensure all services are operational

### Recovery Time Objectives

- **MongoDB Data**: < 30 minutes
- **PVC Restoration**: < 15 minutes
- **Cluster Recreation**: < 45 minutes
- **Total Recovery**: < 90 minutes

### Recovery Procedures

#### Complete Cluster Recovery

```bash
# 1. Recreate infrastructure
cd infrastructure/terraform
terraform apply

# 2. Restore PVCs from snapshots
./scripts/backup/restore-from-snapshots.sh

# 3. Restore MongoDB data
./scripts/backup/mongodb-restore.sh

# 4. Sync secrets from Key Vault
./scripts/secrets/sync-from-keyvault.sh

# 5. Deploy applications
./aks/deployment/deploy-aks-official.sh

# 6. Validate deployment
./scripts/lifecycle/validate-cluster-health.sh
```

#### Data-Only Recovery

```bash
# 1. Restore MongoDB data
./scripts/backup/mongodb-restore.sh

# 2. Restart applications
kubectl rollout restart deployment/rocketchat -n rocketchat

# 3. Validate data integrity
./scripts/backup/backup-validation.sh
```

## 📊 Backup Monitoring

### Key Metrics

- **Backup Success Rate**: Target 100%
- **Backup Size**: Monitor storage usage
- **Recovery Time**: Track restoration performance
- **Data Integrity**: Verify backup completeness

### Monitoring Dashboards

- **Backup Status**: Real-time backup monitoring
- **Storage Usage**: Azure Blob Storage utilization
- **Recovery Metrics**: Restoration performance
- **Alert Status**: Backup failure notifications

### Alert Conditions

- **Backup Failures**: Immediate notification
- **Storage Thresholds**: Storage usage alerts
- **Integrity Issues**: Data corruption alerts
- **Recovery Failures**: Restoration failure alerts

## 🔧 Troubleshooting

### Common Issues

#### MongoDB Backup Failures

**Symptoms**: Backup script fails, no data exported

**Solutions**:
1. Check MongoDB connectivity
2. Verify authentication credentials
3. Ensure sufficient storage space
4. Check Azure Blob Storage permissions

#### PVC Snapshot Issues

**Symptoms**: Snapshots not created, restoration fails

**Solutions**:
1. Verify Azure Disk permissions
2. Check snapshot quotas
3. Ensure sufficient storage space
4. Validate snapshot creation

#### Cluster State Backup Problems

**Symptoms**: Configuration not backed up, restoration incomplete

**Solutions**:
1. Check Kubernetes API connectivity
2. Verify Helm chart access
3. Ensure proper permissions
4. Validate backup compression

### Recovery Testing

#### Regular Testing Schedule

- **Weekly**: Test MongoDB backup restoration
- **Monthly**: Test PVC snapshot restoration
- **Quarterly**: Full disaster recovery testing

#### Testing Procedures

1. **Backup Validation**: Verify backup integrity
2. **Restoration Testing**: Test restore procedures
3. **Data Verification**: Confirm data completeness
4. **Performance Testing**: Measure recovery times

## 📚 Best Practices

### Backup Best Practices

1. **Regular Scheduling**: Automated daily backups
2. **Multiple Locations**: Azure Blob Storage + local copies
3. **Encryption**: Encrypt all sensitive data
4. **Validation**: Regular integrity checks
5. **Retention**: Appropriate retention policies

### Recovery Best Practices

1. **Documentation**: Maintain recovery procedures
2. **Testing**: Regular recovery testing
3. **Monitoring**: Continuous backup monitoring
4. **Automation**: Automated recovery processes
5. **Validation**: Post-recovery verification

### Security Best Practices

1. **Access Control**: Limit backup access
2. **Encryption**: Encrypt all backups
3. **Key Management**: Secure key storage
4. **Audit Logging**: Track backup activities
5. **Compliance**: Meet regulatory requirements

## 🔍 Monitoring and Alerting

### Backup Monitoring

- **Success Rate**: Track backup success percentage
- **Storage Usage**: Monitor Azure Blob Storage usage
- **Performance**: Track backup/restore times
- **Integrity**: Verify backup completeness

### Alert Configuration

- **Backup Failures**: Immediate notification
- **Storage Thresholds**: Proactive storage alerts
- **Recovery Issues**: Restoration failure alerts
- **Data Corruption**: Integrity violation alerts

### Dashboard Metrics

- **Backup Status**: Real-time backup monitoring
- **Storage Utilization**: Azure Blob Storage usage
- **Recovery Performance**: Restoration metrics
- **Alert Status**: Notification tracking

---

**Last Updated**: December 2024  
**Status**: ✅ **FULLY OPERATIONAL** - Complete backup and restore system deployed  
**Next Review**: Monthly backup system review and optimization
