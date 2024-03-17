#!/bin/zsh
install_alias_prereq() {
    brew install jmespath/jmespath/jp
    brew install jq

}

whoiz() {
    aws sts get-caller-identity
}

get_my_ip() {
    dig +short myip.opendns.com @resolver1.opendns.com
}

create_assume_role() {
    aws iam create-role --role-name "${1}" \
    --assume-role-policy-document \
    "{\"Statement\":[{\
        \"Action\":\"sts:AssumeRole\",\
        \"Effect\":\"Allow\",\
        \"Principal\":{\"Service\":\""${2}".amazonaws.com\"},\
        \"Sid\":\"\"\
        }],\
        \"Version\":\"2012-10-17\"\
    }"
}

running_instances() {
    aws ec2 describe-instances \
    --filter Name=instance-state-name,Values=running \
    --output table \
    --query 'Reservations[].Instances[].{ID: InstanceId,Hostname: PublicDnsName,Name: Tags[?Key==`Name`].Value | [0],Type: InstanceType, Platform: Platform || `Linux`}'
}

ebs_volumes() {
    aws ec2 describe-volumes \
    --query 'Volumes[].{VolumeId: VolumeId,State: State,Size: Size,Name: Tags[0].Value,AZ: AvailabilityZone}' \
    --output table;
}

aws_linux_aims() {
    aws ec2 describe-images \
    --filter \
      Name=owner-alias,Values=amazon \
      Name=name,Values="amzn-ami-hvm-*" \
      Name=architecture,Values=x86_64 \
      Name=virtualization-type,Values=hvm \
      Name=root-device-type,Values=ebs \
      Name=block-device-mapping.volume-type,Values=gp2 \
    --query "reverse(sort_by(Images, &CreationDate))[*].[ImageId,Name,Description]" \
    --output text;
}

list_sgs() {
    aws ec2 describe-security-groups --query "SecurityGroups[].[GroupId, GroupName]" --output text;
}

sg_rules() {
    aws ec2 describe-security-groups \
    --query "SecurityGroups[].IpPermissions[].[FromPort,ToPort,IpProtocol,join(',',IpRanges[].CidrIp)]" \
    --group-id "$1" \
    --output text;
}

tostring() {
    jp -f "${1}" 'to_string(@)'
}

jq_to_string() {
    cat "${1}" | jq 'tostring'
}

authorize_my_ip() {
    ip=$(aws myip)
    aws ec2 authorize-security-group-ingress --group-id ${1} --cidr $ip/32 --protocol tcp --port 22
}

get_group_id() {
    aws ec2 describe-security-groups \
    --filters Name=group-name,Values=${1} \
    --query SecurityGroups[0].GroupId \
    --output text
}

authorize_ip_by_name() {
    group_id=$(aws get-group-id "${1}")
    aws authorize-my-ip "$group_id"
}

# list all security group port ranges open to 0.0.0.0/0
public_ports() {
    aws ec2 describe-security-groups \
    --filters Name=ip-permission.cidr,Values=0.0.0.0/0 \
    --query 'SecurityGroups[].{ 
    GroupName:GroupName,
    GroupId:GroupId,
    PortRanges:
      IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)].[
        join(`:`, [IpProtocol, join(`-`, [to_string(FromPort), to_string(ToPort)])])
      ][]
    }'
}

# List or set your region
region() { 
    [[ $# -eq 1 ]] && aws configure set region "$1" || aws configure get region
}

find_acces_key() {
    clear_to_eol=$(tput el)
    for i in $(aws iam list-users --query "Users[].UserName" --output text); do
      printf "\r%sSearching...$i" "${clear_to_eol}"
      result=$(aws iam list-access-keys --output text --user-name "${i}" --query "AccessKeyMetadata[?AccessKeyId=='${1}'].UserName";)
      if [ -n "${result}" ]; then
         printf "\r%s%s is owned by %s.\n" "${lear_to_eol}" "$1" "${result}"
         break
      fi
    done
    if [ -z "${result}" ]; then
      printf "\r%sKey not found." "${clear_to_eol}"
    fi
}

docker_ecr_login() {
    region=$(aws configure get region)
    endpoint=$(aws ecr get-authorization-token --region $region --output text --query authorizationData[].proxyEndpoint)
    passwd=$(aws ecr get-authorization-token --region $region --output text --query authorizationData[].authorizationToken | base64 --decode | cut -d: -f2)
    docker login -u AWS -p $passwd $endpoint
}

allow_my_ip() {
    my_ip=$(aws get_my_ip)
    aws ec2 authorize-security-group-ingress --group-name ${1} --protocol ${2} --port ${3} --cidr $my_ip/32
}

revoke_my_ip() {
    my_ip=$(aws get_my_ip)
    aws ec2 revoke-security-group-ingress --group-name ${1} --protocol ${2} --port ${3} --cidr $my_ip/32
}

allow_my_ip_all() {
    aws allow-my-ip ${1} all all
}

revoke_my_ip_all() {
    aws revoke-my-ip ${1} all all
}