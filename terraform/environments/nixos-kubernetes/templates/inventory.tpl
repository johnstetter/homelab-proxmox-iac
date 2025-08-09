---
all:
  vars:
    ansible_user: ${ssh_user}
    ansible_ssh_private_key_file: ${ssh_private_key}
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

k8s_cluster:
  children:
    control_plane:
      hosts:
%{ for node in control_plane_nodes ~}
        ${node.vm_name}:
          ansible_host: ${node.ip_address}
          node_role: control-plane
          vm_id: ${node.vm_id}
%{ endfor ~}
    workers:
      hosts:
%{ for node in worker_nodes ~}
        ${node.vm_name}:
          ansible_host: ${node.ip_address}
          node_role: worker
          vm_id: ${node.vm_id}
%{ endfor ~}
%{ if load_balancer != null ~}
    load_balancer:
      hosts:
        ${load_balancer.vm_name}:
          ansible_host: ${load_balancer.ip_address}
          node_role: load-balancer
          vm_id: ${load_balancer.vm_id}
%{ endif ~}

# Group variables
control_plane:
  vars:
    node_type: control-plane
    k8s_role: master

workers:
  vars:
    node_type: worker
    k8s_role: node

%{ if load_balancer != null ~}
load_balancer:
  vars:
    node_type: load-balancer
    k8s_role: lb
%{ endif ~}