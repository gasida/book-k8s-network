#!/usr/bin/env bash

echo ">>>> Initial Config Start <<<<"
echo "[TASK 1] Setting Root Password"
printf "qwe123\nqwe123\n" | passwd >/dev/null 2>&1

echo "[TASK 2] Setting Sshd Config"
sed -i "s/^PasswordAuthentication no/PasswordAuthentication yes/g" /etc/ssh/sshd_config
sed -i "s/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g" /etc/ssh/sshd_config
systemctl restart sshd

echo "[TASK 3] Change Timezone & Setting Profile & Bashrc"
# Change Timezone
ln -sf /usr/share/zoneinfo/Asia/Seoul /etc/localtime

#  Setting Profile & Bashrc
echo 'alias vi=vim' >> /etc/profile
echo "sudo su -" >> .bashrc

echo "[TASK 4] Disable ufw & AppArmor"
systemctl stop ufw && systemctl disable ufw >/dev/null 2>&1
systemctl stop apparmor && systemctl disable apparmor >/dev/null 2>&1

echo "[TASK 5] Install Packages"
apt update -qq >/dev/null 2>&1
#apt-get install sshpass net-tools jq tree resolvconf ngrep iputils-arping quagga -y -qq >/dev/null 2>&1
apt-get install sshpass net-tools jq tree resolvconf ngrep iputils-arping -y -qq >/dev/null 2>&1

echo "[TASK 6] Change DNS Server IP Address"
echo -e "nameserver 1.1.1.1" > /etc/resolvconf/resolv.conf.d/head
resolvconf -u

echo "[TASK 7] Setting Local DNS Using Hosts file"
echo "192.168.10.10 k8s-m" >> /etc/hosts
echo "192.168.20.100 k8s-w0" >> /etc/hosts
for (( i=1; i<=$1; i++  )); do echo "192.168.10.10$i k8s-w$i" >> /etc/hosts; done

echo "[TASK 8] Install kubectl"
curl -s -LO https://dl.k8s.io/release/v$2/bin/linux/amd64/kubectl >/dev/null 2>&1
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl >/dev/null 2>&1

echo "[TASK 9] Config kubeconfig"
mkdir -p $HOME/.kube
sshpass -p "qwe123" scp -o StrictHostKeyChecking=no root@k8s-m:/etc/kubernetes/admin.conf $HOME/.kube/config >/dev/null 2>&1

echo "[TASK 10] Source the completion"
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> /etc/profile

echo "[TASK 11] Alias kubectl to k"
echo 'alias k=kubectl' >> /etc/profile
echo 'complete -F __start_kubectl k' >> /etc/profile

echo "[TASK 12] Add Kernel setting - IP Forwarding"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p >/dev/null 2>&1
sysctl --system >/dev/null 2>&1

echo "[TASK 13] Setting Dummy Interface"
modprobe dummy
ip link add loop1 type dummy
ip link set loop1 up
ip addr add 10.1.1.254/24 dev loop1

ip link add loop2 type dummy
ip link set loop2 up
ip addr add 10.1.2.254/24 dev loop2

echo "[TASK 14] Config FRR Software IP routing suite"
apt-get install frr -y -qq >/dev/null 2>&1
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sed -i 's/^#MAX_FDS=1024/MAX_FDS=1024/' /etc/frr/daemons

cat <<EOF > /etc/frr/frr.conf
frr version 8.1
frr defaults traditional
hostname localhost.localdomain
log syslog informational
no ipv6 forwarding
!
router bgp 64512
 no bgp ebgp-requires-policy
 neighbor k8s peer-group
 neighbor k8s remote-as 64512
 bgp listen range 192.168.0.0/16 peer-group k8s
 !
 address-family ipv4 unicast
  network 10.1.1.0/24
  network 10.1.2.0/24
  neighbor k8s soft-reconfiguration inbound
  maximum-paths 4
  maximum-paths ibgp 4
 exit-address-family
!
line vty
!
EOF
systemctl restart frr && systemctl enable bgpd >/dev/null 2>&1

echo "[TASK 15] Install calicoctl Tool - v$3"
curl -L https://github.com/projectcalico/calico/releases/download/v$3/calicoctl-linux-amd64 -o calicoctl >/dev/null 2>&1
chmod +x calicoctl && mv calicoctl /usr/bin

echo ">>>> Initial Config End <<<<"
