# prod environment worker node configuration
{ config, pkgs, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Hostname override
  networking.hostName = "k8s-prod-worker";

  # Kubernetes worker node configuration
  services.kubernetes = {
    roles = [ "node" ];
    masterAddress = "k8s-prod-control";

    # Kubelet configuration
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
      tlsCertFile = "/var/lib/kubelet/kubelet.pem";
      tlsPrivateKeyFile = "/var/lib/kubelet/kubelet-key.pem";
      clientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeconfig = "/var/lib/kubelet/kubeconfig";
      
      # Worker-specific settings
      maxPods = 110;
      containerRuntime = "containerd";
      containerRuntimeEndpoint = "unix:///run/containerd/containerd.sock";
    };

    # Kube-proxy configuration
    proxy = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      kubeconfig = "/var/lib/kube-proxy/kubeconfig";
    };
  };

  # Worker node firewall rules
  networking.firewall.allowedTCPPorts = [ 
    10250  # Kubelet API
    30000  # NodePort services start
    32767  # NodePort services end
  ];

  networking.firewall.allowedTCPPortRanges = [
    { from = 30000; to = 32767; }  # NodePort services
  ];

  # CNI plugins
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
  ];

  # Environment-specific settings
  environment.variables = {
    K8S_ENV = "prod";
    NODE_ROLE = "worker";
  };

  # Additional worker node optimizations
  boot.kernel.sysctl = {
    "vm.max_map_count" = 262144;
    "fs.inotify.max_user_instances" = 8192;
    "fs.inotify.max_user_watches" = 524288;
  };
}
