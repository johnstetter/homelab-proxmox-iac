# TODO List - NixOS Kubernetes Infrastructure

## 🔥 High Priority - Phase 1 Completion

### Infrastructure & Backend
- [ ] **Configure S3 + DynamoDB backend** - Set up remote state management with proper IAM permissions
- [ ] **Update terraform.tfvars** - Populate with actual Proxmox connection details
- [ ] **Test Terraform deployment** - Validate complete infrastructure provisioning
- [ ] **Create GitLab runner setup** - Document local runner configuration for homelab

### Security & Access
- [ ] **Implement proper IAM roles** - Create least-privilege AWS IAM for Terraform backend
- [ ] **Add Proxmox API token creation** - Document secure token generation process
- [ ] **Review SSH key security** - Ensure proper key rotation and access controls
- [ ] **Add .gitignore improvements** - Ensure no sensitive data is committed

## 🚀 Medium Priority - Phase 2 Implementation

### NixOS Configuration
- [ ] **Populate empty NixOS configs** - Run `./scripts/populate-nixos-configs.sh` and customize
- [ ] **Test NixOS ISO generation** - Validate `nixos-generators` workflow
- [ ] **Create Proxmox templates** - Upload ISOs and create VM templates
- [ ] **Add cloud-init validation** - Ensure NixOS cloud-init works properly

### Automation & Scripts
- [ ] **Fix script permissions** - Ensure all scripts in `scripts/` are executable
- [ ] **Add error handling** - Improve script robustness and error reporting
- [ ] **Create rollback procedures** - Add infrastructure rollback mechanisms
- [ ] **Add monitoring/alerting** - Basic health checks for deployed infrastructure

## 🔧 Low Priority - Future Enhancements

### Phase 3 - Kubernetes Installation
- [ ] **Research kubeadm vs nix-k3s** - Choose Kubernetes installation method
- [ ] **Design CNI networking** - Plan Flannel or Calico implementation
- [ ] **Add cluster bootstrapping** - Automated cluster initialization
- [ ] **Create node joining process** - Automated worker node addition

### Documentation & Maintenance
- [ ] **Add troubleshooting guide** - Common issues and solutions
- [ ] **Create architecture diagrams** - Visual representation of infrastructure
- [ ] **Add backup/restore procedures** - Data protection strategies
- [ ] **Performance optimization** - Resource allocation tuning

### CI/CD Pipeline
- [ ] **Complete GitLab CI pipeline** - Fix `.gitlab-ci.yml` implementation
- [ ] **Add automated testing** - Infrastructure validation tests
- [ ] **Create deployment environments** - Separate dev/staging/prod pipelines
- [ ] **Add security scanning** - Terraform security analysis

## 🐛 Known Issues & Fixes Needed

### Current Problems
- [ ] **Empty configuration files** - Multiple config files contain only comments
- [ ] **Missing terraform.tfvars** - Need to copy from example and populate
- [ ] **Unvalidated Terraform** - Need to run `terraform validate` and fix issues
- [ ] **Script execution permissions** - Run `chmod +x scripts/*.sh`

### Technical Debt
- [ ] **Hardcoded values** - Remove magic numbers and hardcoded IPs
- [ ] **Error handling** - Add proper error handling in Terraform modules
- [ ] **Resource naming** - Implement consistent naming conventions
- [ ] **Module versioning** - Pin Terraform module versions

## 📋 Configuration Requirements

### Prerequisites Setup
- [ ] **Install nixos-generators** - `nix-env -iA nixpkgs.nixos-generators`
- [ ] **Configure AWS credentials** - For S3/DynamoDB backend access
- [ ] **Set up Proxmox API access** - Create API token with proper permissions
- [ ] **Configure GitLab runner** - Set up local runner with `homelab` tag

### Environment Variables
- [ ] **AWS_ACCESS_KEY_ID** - For Terraform backend
- [ ] **AWS_SECRET_ACCESS_KEY** - For Terraform backend
- [ ] **PROXMOX_API_URL** - Proxmox server endpoint
- [ ] **PROXMOX_API_TOKEN** - API authentication token

## 🎯 Next Immediate Actions

1. **Set up S3 + DynamoDB backend** (see S3-DYNAMODB-SETUP.md)
2. **Populate terraform.tfvars** with real values
3. **Run terraform init && terraform plan** to validate configuration
4. **Execute NixOS scripts** to populate configurations
5. **Test complete deployment** with `terraform apply`

## 📊 Progress Tracking

### Phase 1 - Terraform + Proxmox ✅
- ✅ Terraform root module structure
- ✅ Proxmox VM module implementation
- ✅ Variable definitions and outputs
- ✅ Template files for inventory/kubeconfig
- ⏳ Backend configuration (S3/DynamoDB)
- ⏳ GitLab CI/CD pipeline

### Phase 2 - NixOS Configuration ⏳
- ⏳ NixOS configuration population
- ⏳ ISO generation with nixos-generators
- ⏳ Proxmox template creation
- ⏳ Validation and testing

### Phase 3 - Kubernetes Installation ⏸️
- ⏸️ Cluster initialization
- ⏸️ CNI network setup
- ⏸️ Node joining automation
- ⏸️ Basic cluster validation

## 🔗 Related Documentation

- [COMMIT-STRATEGY.md](./COMMIT-STRATEGY.md) - Git commit guidelines
- [README-phase2.md](./README-phase2.md) - Phase 2 implementation guide
- [terraform/README.md](./terraform/README.md) - Terraform usage documentation
- [CLAUDE.md](./CLAUDE.md) - Claude Code integration guide

---

**Last Updated**: Auto-generated during codebase analysis
**Priority**: Focus on Phase 1 completion before moving to Phase 2