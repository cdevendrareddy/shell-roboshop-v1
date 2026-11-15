#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
subnet_id="subnet-048a967ae46eb356b"
domain_name="opsbydev.online"
hosted_zone_id="Z0041306Z9IINAP57ERG"

common_sg="sg-02f919d5271d64a6b"
mongodb_sg="sg-0186f53f5af68234c"
user_sg="sg-077916cda9d29f844"
catalogue_sg="sg-0bab365385b2b3799"

for instance in "$@"
do
    echo "Creating instance: $instance"

    case "$instance" in
        mongodb) service_sg="$mongodb_sg" ;;
        user) service_sg="$user_sg" ;;
        catalogue) service_sg="$catalogue_sg" ;;
        *) echo "Invalid service: $instance"; exit 1 ;;
    esac

    instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --instance-type "$instance_type" \
        --security-group-ids "$common_sg" "$service_sg" \
        --subnet-id "$subnet_id" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
        --query 'Instances[0].InstanceId' \
        --output text)

    echo "$instance instance id: $instance_id"
done