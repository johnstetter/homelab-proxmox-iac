# NixOS Kubernetes control plane role configuration using native services.kubernetes module
{ config, pkgs, lib, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Override hostname to be set by cloud-init
  networking.hostName = lib.mkDefault "k8s-control-plane";

  # Native Kubernetes control plane configuration with easyCerts
  services.kubernetes = {
    roles = [ "master" ];
    masterAddress = lib.mkDefault "k8s-control-plane";
    
    # Enable automatic certificate management
    easyCerts = true;
    
    # Cluster network configuration
    clusterCidr = "10.244.0.0/16";
    serviceCidr = "10.96.0.0/12";
    
    # API Server configuration
    apiserver = {
      enable = true;
      bindAddress = "0.0.0.0";
      advertiseAddress = lib.mkDefault null; # Will be auto-detected
      allowPrivileged = true;
      authorizationMode = [ "RBAC" "Node" ];
      serviceClusterIpRange = "10.96.0.0/12";
      securePort = 6443;
      extraOpts = {
        enable-admission-plugins = "NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,NodeRestriction";
        runtime-config = "api/all=true";
      };
    };

    # Controller Manager configuration
    controllerManager = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      serviceCidr = "10.96.0.0/12";
      extraOpts = {
        cluster-signing-cert-file = "/var/lib/kubernetes/ca.pem";
        cluster-signing-key-file = "/var/lib/kubernetes/ca-key.pem";
        use-service-account-credentials = "true";
        leader-elect = "true";
      };
    };

    # Scheduler configuration
    scheduler = {
      enable = true;
      bindAddress = "0.0.0.0";
      extraOpts = {
        leader-elect = "true";
      };
    };

    # Etcd configuration for single-node or multi-node cluster
    etcd = {
      enable = true;
      listenClientUrls = [ "https://0.0.0.0:2379" ];
      listenPeerUrls = [ "https://0.0.0.0:2380" ];
      advertiseClientUrls = [ "https://${config.networking.hostName}:2379" ];
      initialAdvertisePeerUrls = [ "https://${config.networking.hostName}:2380" ];
      initialCluster = [ "${config.networking.hostName}=https://${config.networking.hostName}:2380" ];
      dataDir = "/var/lib/etcd";
      extraOpts = {
        initial-cluster-state = "new";
        enable-v2 = "false";
        logger = "zap";
        log-level = "info";
      };
    };

    # Kubelet configuration for control plane
    kubelet = {
      enable = true;
      registerNode = true;
      address = "0.0.0.0";
      port = 10250;
      clusterDns = "10.96.0.10";
      clusterDomain = "cluster.local";
      networkPlugin = "cni";
      cniConfDir = "/etc/cni/net.d";
      cniBinDir = "/opt/cni/bin";
      extraOpts = {
        node-labels = "node-role.kubernetes.io/control-plane=,node-role.kubernetes.io/master=";
        register-with-taints = "node-role.kubernetes.io/control-plane=:NoSchedule";
        container-runtime = "containerd";
        container-runtime-endpoint = "unix:///run/containerd/containerd.sock";
        resolv-conf = "/run/systemd/resolve/resolv.conf";
        cgroup-driver = "systemd";
        fail-swap-on = "false";
        max-pods = "110";
        pod-infra-container-image = "registry.k8s.io/pause:3.9";
      };
    };

    # Kube-proxy configuration
    proxy = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      extraOpts = {
        proxy-mode = "iptables";
        cluster-cidr = "10.244.0.0/16";
      };
    };

    # Flannel CNI configuration
    flannel = {
      enable = true;
      network = "10.244.0.0/16";
      backend = {
        type = "vxlan";
        port = 8472;
      };
      iface = lib.mkDefault null; # Auto-detect network interface
    };
  };

  # Control plane specific firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      6443   # Kubernetes API server
      2379   # etcd client requests
      2380   # etcd peer communication
      10250  # Kubelet API
      10251  # kube-scheduler
      10252  # kube-controller-manager
      10257  # kube-controller-manager healthz
      10259  # kube-scheduler healthz
    ];
    allowedUDPPorts = [ 
      8472   # Flannel VXLAN
    ];
  };

  # Additional packages for control plane
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
    kubernetes-helm
    etcd
    nfs-utils
  ];

  # Environment variables for kubectl access
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    K8S_ROLE = "control-plane";
  };

  # Systemd service for kubeconfig setup
  systemd.services.setup-kubeconfig = {
    description = "Setup kubeconfig for admin access";
    after = [ "kubernetes-apiserver.service" ];
    wants = [ "kubernetes-apiserver.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "setup-kubeconfig" ''
        set -e
        mkdir -p /etc/kubernetes
        if [ ! -f /etc/kubernetes/admin.conf ]; then
          ${pkgs.kubernetes}/bin/kubectl config set-cluster default \
            --certificate-authority=/var/lib/kubernetes/ca.pem \
            --embed-certs=true \
            --server=https://localhost:6443 \
            --kubeconfig=/etc/kubernetes/admin.conf
          ${pkgs.kubernetes}/bin/kubectl config set-credentials admin \
            --client-certificate=/var/lib/kubernetes/admin.pem \
            --client-key=/var/lib/kubernetes/admin-key.pem \
            --embed-certs=true \
            --kubeconfig=/etc/kubernetes/admin.conf
          ${pkgs.kubernetes}/bin/kubectl config set-context default \
            --cluster=default \
            --user=admin \
            --kubeconfig=/etc/kubernetes/admin.conf
          ${pkgs.kubernetes}/bin/kubectl config use-context default \
            --kubeconfig=/etc/kubernetes/admin.conf
          chmod 600 /etc/kubernetes/admin.conf
        fi
      '';
    };
  };

  # Optimization for control plane workloads
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 524288;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 12582912 16777216";
    "net.ipv4.tcp_wmem" = "4096 12582912 16777216";
  };

  # NFS client configuration
  services.rpcbind.enable = true;

  # NFS mount for Synology cluster storage
  fileSystems."/mnt/nfs" = {
    device = "192.168.1.4:/volume1/k8s-cluster-storage";
    fsType = "nfs";
    options = [ "nfsvers=4" "rsize=1048576" "wsize=1048576" "hard" "intr" ];
  };
}