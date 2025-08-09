apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: <CERTIFICATE_AUTHORITY_DATA>
    server: https://${control_plane_ip}:${control_plane_port}
  name: ${cluster_name}
contexts:
- context:
    cluster: ${cluster_name}
    user: ${cluster_name}-admin
  name: ${cluster_name}
current-context: ${cluster_name}
users:
- name: ${cluster_name}-admin
  user:
    client-certificate-data: <CLIENT_CERTIFICATE_DATA>
    client-key-data: <CLIENT_KEY_DATA>

# Instructions:
# 1. Replace <CERTIFICATE_AUTHORITY_DATA> with the base64-encoded CA certificate
# 2. Replace <CLIENT_CERTIFICATE_DATA> with the base64-encoded client certificate
# 3. Replace <CLIENT_KEY_DATA> with the base64-encoded client key
# 
# These values can be obtained from the Kubernetes cluster after initialization:
# - CA certificate: /etc/kubernetes/pki/ca.crt
# - Client certificate: /etc/kubernetes/pki/apiserver-kubelet-client.crt
# - Client key: /etc/kubernetes/pki/apiserver-kubelet-client.key
#
# To encode to base64: cat <file> | base64 -w 0