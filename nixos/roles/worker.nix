# NixOS Kubernetes worker node role configuration using native services.kubernetes module
{ config, pkgs, lib, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Override hostname to be set by cloud-init
  networking.hostName = lib.mkDefault "k8s-worker";

  # Native Kubernetes worker node configuration with easyCerts
  services.kubernetes = {
    roles = [ "node" ];
    masterAddress = lib.mkDefault "k8s-control-plane"; # Will be overridden by cloud-init
    
    # Enable automatic certificate management
    easyCerts = true;
    
    # Cluster network configuration
    clusterCidr = "10.244.0.0/16";
    serviceCidr = "10.96.0.0/12";

    # Kubelet configuration for worker nodes
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
        node-labels = "node-role.kubernetes.io/worker=";
        container-runtime = "containerd";
        container-runtime-endpoint = "unix:///run/containerd/containerd.sock";
        resolv-conf = "/run/systemd/resolve/resolv.conf";
        cgroup-driver = "systemd";
        fail-swap-on = "false";
        max-pods = "110";
        pod-infra-container-image = "registry.k8s.io/pause:3.9";
        read-only-port = "0";
        anonymous-auth = "false";
        authorization-mode = "Webhook";
        client-ca-file = "/var/lib/kubernetes/ca.pem";
        cluster-dns = "10.96.0.10";
        cluster-domain = "cluster.local";
        runtime-request-timeout = "15m";
        volume-plugin-dir = "/usr/libexec/kubernetes/kubelet-plugins/volume/exec/";
        
        # Resource management
        enforce-node-allocatable = "pods";
        kube-reserved = "cpu=100m,memory=200Mi,ephemeral-storage=1Gi";
        system-reserved = "cpu=100m,memory=200Mi,ephemeral-storage=1Gi";
        eviction-hard = "memory.available<100Mi,nodefs.available<10%,nodefs.inodesFree<5%";
        eviction-soft = "memory.available<300Mi,nodefs.available<15%";
        eviction-soft-grace-period = "memory.available=1m30s,nodefs.available=1m30s";
        eviction-max-pod-grace-period = "30";
        
        # Logging and monitoring
        v = "2";
        logtostderr = "true";
        log-file-max-size = "100";
        log-flush-frequency = "5s";
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
        masquerade-all = "false";
        metrics-bind-address = "0.0.0.0:10249";
        v = "2";
        logtostderr = "true";
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

  # Worker node specific firewall configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      10250  # Kubelet API
      10256  # kube-proxy healthz
    ];
    allowedTCPPortRanges = [
      { from = 30000; to = 32767; }  # NodePort services
    ];
    allowedUDPPorts = [ 
      8472   # Flannel VXLAN
    ];
  };

  # Worker-specific packages
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
    nfs-utils
    # Additional tools for troubleshooting
    tcpdump
    iftop
    iotop
    strace
  ];

  # Environment variables
  environment.variables = {
    K8S_ROLE = "worker";
    NODE_ROLE = "worker";
  };

  # Worker node optimizations
  boot.kernel.sysctl = {
    # Memory management
    "vm.max_map_count" = 262144;
    "vm.swappiness" = 1;
    "vm.overcommit_memory" = 1;
    "vm.panic_on_oom" = 0;
    "vm.vfs_cache_pressure" = 50;
    
    # File system
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 524288;
    "fs.file-max" = 2097152;
    "fs.nr_open" = 1048576;
    
    # Network optimization
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rmem_default" = 262144;
    "net.core.wmem_default" = 262144;
    "net.core.optmem_max" = 25165824;
    "net.core.netdev_max_backlog" = 5000;
    "net.ipv4.tcp_rmem" = "4096 12582912 16777216";
    "net.ipv4.tcp_wmem" = "4096 12582912 16777216";
    "net.ipv4.tcp_max_syn_backlog" = 8096;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.ip_local_port_range" = "10240 65535";
    
    # Connection tracking
    "net.netfilter.nf_conntrack_max" = 1000000;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 86400;
    "net.netfilter.nf_conntrack_tcp_timeout_time_wait" = 30;
    
    # Process limits
    "kernel.pid_max" = 4194304;
    "kernel.threads-max" = 1000000;
    
    # Kubernetes specific
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Systemd resource limits for containers
  systemd.extraConfig = ''
    DefaultLimitNOFILE=1048576
    DefaultLimitNPROC=1048576
  '';

  # User resource limits
  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "1048576";
    }
    {
      domain = "*";
      type = "soft";
      item = "nproc";
      value = "1048576";
    }
    {
      domain = "*";
      type = "hard";
      item = "nproc";
      value = "1048576";
    }
  ];

  # Containerd optimizations for worker nodes
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri" = {
      systemd_cgroup = true;
      sandbox_image = "registry.k8s.io/pause:3.9";
      max_container_log_line_size = 16384;
      max_concurrent_downloads = 10;
      
      # Registry configuration
      registry = {
        mirrors = {
          "docker.io" = {
            endpoint = [ "https://registry-1.docker.io" ];
          };
          "registry.k8s.io" = {
            endpoint = [ "https://registry.k8s.io" ];
          };
        };
      };
      
      # CNI configuration
      cni = {
        bin_dir = "/opt/cni/bin";
        conf_dir = "/etc/cni/net.d";
        max_conf_num = 1;
        conf_template = "";
      };
    };
    
    # Storage optimization
    plugins."io.containerd.snapshotter.v1.overlayfs" = {
      root_path = "/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs";
    };
  };

  # NFS client configuration
  services.rpcbind.enable = true;

  # NFS mount for Synology cluster storage
  fileSystems."/mnt/nfs" = {
    device = "192.168.1.4:/volume1/k8s-cluster-storage";
    fsType = "nfs";
    options = [ "nfsvers=4" "rsize=1048576" "wsize=1048576" "hard" "intr" ];
  };

  # Monitoring and log rotation
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/pods/*/*/*.log" = {
        frequency = "daily";
        rotate = 7;
        missingok = true;
        notifempty = true;
        sharedscripts = true;
        postrotate = "systemctl reload containerd || true";
      };
    };
  };
}