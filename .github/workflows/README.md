# 🚀 GitHub Actions Setup Guide

## 📋 Overview

This guide explains how to set up the dbt CI/CD pipeline using GitHub Actions for the GotPhoto project.

## 🔧 Required Setup

### **1. GitHub Secrets Configuration**

Navigate to your GitHub repository:
```
Settings → Secrets and variables → Actions → New repository secret
```

Add the following secrets:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SNOWFLAKE_ACCOUNT` | Your Snowflake account identifier | `xy12345.us-east-1` |
| `SNOWFLAKE_USER` | Snowflake username | `devops_dbt_user` |
| `SNOWFLAKE_PASSWORD` | Snowflake password | `**********!` |
| `SNOWFLAKE_ROLE` | Snowflake role with necessary permissions | `devops_dbt_role` |
| `SNOWFLAKE_DATABASE` | Target database name | `GOTPHOTO_ANALYTICS_DB` |
| `SNOWFLAKE_WAREHOUSE` | Snowflake warehouse name | `COMPUTE_WH` |

### **2. Snowflake Setup**

Run the `snowflake_devops_setup.sql` script as ACCOUNTADMIN to create the DevOps user and role with all necessary permissions.

### **3. Workflow Files**

We use a **single combined workflow**:

1. **`dbt-ci-cd.yml`** - Handles both PR validation and production deployment

## 🔄 Workflow Execution

### **PR Validation Flow**
```
1. PR Created → Clone Database → Validate Project → Run Changed Models → Cleanup
2. Expected Time: 2-5 minutes
3. Cost: ~$0.50-2.00 per PR
```

### **Production Deployment Flow**
```
1. PR Merged to Main → Validate Project → Full-Refresh Changed Models → Test
2. Expected Time: 5-15 minutes
3. Cost: ~$1.00-5.00 per deployment
```

## 🧪 Testing the Setup

### **1. Create a Test PR**
1. Create a new branch
2. Make a small change to a dbt model
3. Create a PR against main
4. Check the GitHub Actions tab

### **2. Verify PR Validation**
- ✅ Database cloning successful
- ✅ dbt debug passes
- ✅ dbt compile passes
- ✅ Changed models run successfully
- ✅ Database cleanup completed

### **3. Test Production Deployment**
- ✅ Merge PR to main
- ✅ Verify production deployment runs
- ✅ Check that models are deployed to prod schema

## ⚠️ Troubleshooting

### **Common Issues**

#### **1. Database Cloning Fails**
```bash
# Error: Insufficient privileges
# Solution: Grant CREATE DATABASE permission
GRANT CREATE DATABASE ON ACCOUNT TO ROLE dbt_ci_role;
```

#### **2. dbt Debug Fails**
```bash
# Error: Connection failed
# Solution: Check Snowflake credentials and network access
```

#### **3. State Comparison Issues**
```bash
# Error: Cannot determine changed models
# Solution: Ensure fetch-depth: 0 in checkout action
```

#### **4. Permission Denied**
```bash
# Error: Access denied to schema/table
# Solution: Grant appropriate privileges to dbt_ci_role
```

### **Debug Steps**
1. Check GitHub Actions logs
2. Verify Snowflake credentials
3. Test connection manually
4. Check Snowflake query history

## 📊 Monitoring

### **GitHub Actions Dashboard**
- Monitor workflow execution times
- Track success/failure rates
- Review logs for issues

### **Snowflake Monitoring**
- Monitor warehouse usage
- Track credit consumption
- Review query performance

## 🔒 Security Considerations

### **1. Credential Management**
- Use dedicated CI/CD user
- Rotate passwords regularly
- Limit role permissions

### **2. Database Access**
- Isolated PR environments
- Automatic cleanup
- No production interference

### **3. Network Security**
- Snowflake network policies
- IP allowlisting if required
- Secure credential storage

## 📈 Cost Optimization

### **1. Warehouse Sizing**
- Use smaller warehouse for PR validation
- Scale up for production deployment
- Auto-suspend when idle

### **2. Execution Optimization**
- Only run changed models
- Minimize full-refresh usage
- Efficient state comparison

### **3. Resource Management**
- Automatic cleanup of PR databases
- Monitor credit usage
- Optimize query performance

## 🚀 Next Steps

1. **Configure secrets** in GitHub repository
2. **Set up Snowflake permissions**
3. **Test with a sample PR**
4. **Monitor and optimize**
5. **Scale as needed**

---

## 📝 Summary

This setup provides a **fast, cost-effective, and reliable** CI/CD pipeline for your dbt project. The database cloning strategy ensures isolated testing while the git-based state management provides efficient change detection.

**Key Benefits:**
- ✅ Fast PR validation (2-5 minutes)
- ✅ Cost-effective execution
- ✅ Isolated testing environment
- ✅ Automated deployment process 