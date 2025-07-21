# dev environment control plane configuration
{ config, pkgs, ... }:

{
  imports = [ ../common/configuration.nix ];

  # Hostname override
  networking.hostName = "k8s-dev-control";

  # Kubernetes control plane configuration
  services.kubernetes = {
    roles = [ "master" ];
    masterAddress = "k8s-dev-control";
    
    # API Server configuration
    apiserver = {
      enable = true;
      advertiseAddress = "0.0.0.0";
      allowPrivileged = true;
      authorizationMode = [ "RBAC" "Node" ];
      enable = true;
      etcd = {
        servers = [ "https://127.0.0.1:2379" ];
        caFile = "/var/lib/kubernetes/ca.pem";
        certFile = "/var/lib/kubernetes/kubernetes.pem";
        keyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      };
      serviceClusterIpRange = "10.96.0.0/12";
      securePort = 6443;
      tlsCertFile = "/var/lib/kubernetes/kubernetes.pem";
      tlsPrivateKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      clientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeletClientCaFile = "/var/lib/kubernetes/ca.pem";
      kubeletClientCertFile = "/var/lib/kubernetes/kubernetes.pem";
      kubeletClientKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      serviceAccountKeyFile = "/var/lib/kubernetes/service-account.pem";
      serviceAccountSigningKeyFile = "/var/lib/kubernetes/service-account-key.pem";
    };

    # Controller Manager configuration
    controllerManager = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      serviceCidr = "10.96.0.0/12";
      tlsCertFile = "/var/lib/kubernetes/kube-controller-manager.pem";
      tlsPrivateKeyFile = "/var/lib/kubernetes/kube-controller-manager-key.pem";
      serviceAccountPrivateKeyFile = "/var/lib/kubernetes/service-account-key.pem";
      rootCaFile = "/var/lib/kubernetes/ca.pem";
    };

    # Scheduler configuration
    scheduler = {
      enable = true;
      bindAddress = "0.0.0.0";
    };

    # Etcd configuration
    etcd = {
      enable = true;
      listenClientUrls = [ "https://127.0.0.1:2379" ];
      listenPeerUrls = [ "https://127.0.0.1:2380" ];
      advertiseClientUrls = [ "https://127.0.0.1:2379" ];
      initialAdvertisePeerUrls = [ "https://127.0.0.1:2380" ];
      initialCluster = [ "k8s-dev-control=https://127.0.0.1:2380" ];
      dataDir = "/var/lib/etcd";
      certFile = "/var/lib/kubernetes/kubernetes.pem";
      keyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      trustedCaFile = "/var/lib/kubernetes/ca.pem";
      peerCertFile = "/var/lib/kubernetes/kubernetes.pem";
      peerKeyFile = "/var/lib/kubernetes/kubernetes-key.pem";
      peerTrustedCaFile = "/var/lib/kubernetes/ca.pem";
    };

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
    };

    # Kube-proxy configuration
    proxy = {
      enable = true;
      bindAddress = "0.0.0.0";
      clusterCidr = "10.244.0.0/16";
      kubeconfig = "/var/lib/kube-proxy/kubeconfig";
    };
  };

  # Additional firewall rules for control plane
  networking.firewall.allowedTCPPorts = [ 
    6443   # Kubernetes API server
    2379   # etcd client requests
    2380   # etcd peer communication
    10250  # Kubelet API
    10251  # kube-scheduler
    10252  # kube-controller-manager
  ];

  # CNI plugins
  environment.systemPackages = with pkgs; [
    cni-plugins
    flannel
  ];

  # Environment-specific settings
  environment.variables = {
    KUBECONFIG = "/etc/kubernetes/admin.conf";
    K8S_ENV = "dev";
  };
}
