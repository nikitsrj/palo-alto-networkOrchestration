#!/bin/bash
VLAN_ID=$1
VLAN_NAME=$2
VLAN_IPADDRESS=$3
VLAN_SUBNETMASK=$4
echo "**********************************Configuring L2 Switch************************"
cd /root/workspace/NetworkOrchestrationPOC/L2
>/var/log/ansible.log
ansible-playbook playbook.yaml -i hosts -e vlanId=${VLAN_ID} -e vlanName=${VLAN_NAME}
cat /var/log/ansible.log | grep -i 'skipped=1'
ES=`echo $?`
if [ $ES -eq 0 ]
then 
   echo "VLAN ID Already Exists in L2switch"
else
echo "VLAN has been configured in L2 switch"
fi
> /var/log/ansible.log
echo "**********************************Configuring L3 Switch************************"
cd /root/workspace/NetworkOrchestrationPOC/L3
ansible-playbook playbook.yaml -i hosts -e vlanId=${VLAN_ID} -e vlanName=${VLAN_NAME} -e ipAddr=${VLAN_IPADDRESS} -e subNet=${VLAN_SUBNETMASK}
cat /var/log/ansible.log | grep -i 'skipped=1'
ES=`echo $?`
if [ $ES -eq 0 ]
then 
   echo "VLAN ID Already Exists in L3 switch"
else
echo "VLAN has been configured L3 switch"
fi
echo "**********************************Configuring firewall************************"
######################Local Variable#########
OBJECTNAME=${VLAN_ID}_${VLAN_NAME}
NETWORK=`ipcalc -n ${VLAN_IPADDRESS} ${VLAN_SUBNETMASK} | sed -n 's/NETWORK=//p'`
PREFIX=`ipcalc -p ${VLAN_IPADDRESS} ${VLAN_SUBNETMASK} | sed -n 's/PREFIX=//p'`
IPNETMASK=$NETWORK/$PREFIX
#############################################Object Creation########################

curl -v -k -X POST "https://172.20.191.195/restapi/9.0/Objects/Addresses?location=vsys&vsys=vsys1&key=LUFRPT1aM0Zma3AzRjVUbnlPMzZGSU9BdUVqVHBUZFE9bVZMNFlIWm0yQlZxbVFTYkx4M3h4QVpuQU9qVEh6T3B2THZPdnRCMnNqWWUxMk41UkZGSW5FNWtqRHBlUEt4YQ==&name=$OBJECTNAME" -d '{ "entry": [ { "@name": "'"$OBJECTNAME"'", "ip-netmask": "'"$IPNETMASK"'", "description": "VLANOBJECTPOC" }]}'

#############################Rule Creation##################
curl -k -v -X --location --request POST "https://172.20.191.195/restapi/v10.0/Policies/SecurityRules?name=RDP_SVR_toSvr_Net_$OBJECTNAME&location=vsys&vsys=vsys1" \
--header 'X-PAN-KEY: LUFRPT1aM0Zma3AzRjVUbnlPMzZGSU9BdUVqVHBUZFE9bVZMNFlIWm0yQlZxbVFTYkx4M3h4QVpuQU9qVEh6T3B2THZPdnRCMnNqWWUxMk41UkZGSW5FNWtqRHBlUEt4YQ==' \
--header 'Content-Type: application/json' \
--header 'Cookie: PHPSESSID=ef34ecbaf287f8814493d224890759a5' \
-d '{
  "entry": [ {
    "@name": "'"RDP_SVR_toSvr_Net_$OBJECTNAME"'",
    "from": {
      "member": [
        "any"
      ]
    },
    "to": {
      "member": [
        "any"
      ]
    },
    "source": {
      "member": [
        "172.31.238.251"
      ]
    },
    "source-user": {
      "member": [
        "any"
      ]
    },
    "destination": {
      "member": [
        "'"$OBJECTNAME"'"
      ]
    },
    "service": {
      "member": [
        "application-default"
      ]
    },
    "category": {
      "member": [
        "any"
      ]
    },
    "application": {
      "member": [
        "ms-rdp",
        "ping"
      ]
    },
    "source-imsi": {
      "member": [
        "any"
      ]
    },
    "source-imei": {
      "member": [
        "any"
      ]
    },
    "source-nw-slice": {
      "member": [
        "any"
      ]
    },
    "source-hip": {
      "member": [
        "any"
      ]
    },
    "destination-hip": {
      "member": [
        "any"
      ]
    },
    "negate-source": "no",
    "negate-destination": "no",
    "disabled": "no",
    "hip-profiles": {
      "member": [
        "any"
      ]
    },
    "action": "allow",
    "icmp-unreachable": "no",
    "rule-type": "universal",
    "option": {
      "disable-server-response-inspection": "no"
    },
    "log-start": "no",
    "log-end": "yes"
      
      
    }
    
    ]
}'

######################## Update the virtual Router #############################
curl -k -v -X --location --request GET 'https://172.20.191.195/restapi/v10.0/Network/VirtualRouters?@name=default' --header 'X-PAN-KEY: LUFRPT1aM0Zma3AzRjVUbnlPMzZGSU9BdUVqVHBUZFE9bVZMNFlIWm0yQlZxbVFTYkx4M3h4QVpuQU9qVEh6T3B2THZPdnRCMnNqWWUxMk41UkZGSW5FNWtqRHBlUEt4YQ==' | jq .[] | sed '1,2d' | sed '2,3d' > getVirtualRouter.json

cat getVirtualRouter.json | jq '.entry[]."routing-table".ip."static-route".entry |= . + [{"@name":"'"$OBJECTNAME"'","path-monitor":{"enable":"no","failure-condition":"any","hold-time":"2"},"nexthop":{"ip-address":"172.31.238.238"},"bfd":{"profile":"None"},"interface":"ethernet1/2","metric":"10","destination":"'"$OBJECTNAME"'","route-table":{"unicast":{}}}]' | sponge getVirtualRouter.json

curl -k -v -X --location --request PUT 'https://172.20.191.195/restapi/v10.0/Network/VirtualRouters?@name=default' --header 'X-PAN-KEY: LUFRPT1aM0Zma3AzRjVUbnlPMzZGSU9BdUVqVHBUZFE9bVZMNFlIWm0yQlZxbVFTYkx4M3h4QVpuQU9qVEh6T3B2THZPdnRCMnNqWWUxMk41UkZGSW5FNWtqRHBlUEt4YQ==' --header 'Content-Type: application/json' --header 'Cookie: PHPSESSID=ef34ecbaf287f8814493d224890759a5' -d @getVirtualRouter.json


#######################Commit the changes in Firewall###########################



curl -k -v 'https://172.20.191.195/api/?key=LUFRPT1aM0Zma3AzRjVUbnlPMzZGSU9BdUVqVHBUZFE9bVZMNFlIWm0yQlZxbVFTYkx4M3h4QVpuQU9qVEh6T3B2THZPdnRCMnNqWWUxMk41UkZGSW5FNWtqRHBlUEt4YQ==&type=commit&cmd=<commit></commit>'





