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
shipping_sg="sg-08de5b70d9118f85f"
redis_sg="sg-0c3cad5b735e94c9c"
rabbitmq_sg="sg-0f2a1a18e5a225453"
payment_sg="sg-0b9422098a44b9fec"
mysql_sg="sg-066fee7872d6b97a0"
frontend_sg="sg-0889c7aa362431c68"
dispatch_sg="sg-00dbbdee2ea212b05"
cart_sg="sg-0c0474dcd4e49ec9b"

for instance in "$@"
do
    echo "Creating instance: $instance"

    case "$instance" in
        mongodb) service_sg="$mongodb_sg" ;;
        user) service_sg="$user_sg" ;;
        catalogue) service_sg="$catalogue_sg" ;;
        shipping) service_sg="$shipping_sg" ;;
        redis) service_sg="$redis_sg" ;;
        rabbitmq) service_sg="$rabbitmq_sg" ;;
        payment) service_sg="$payment_sg" ;;
        mysql) service_sg="$mysql_sg" ;;
        frontend) service_sg="$frontend_sg" ;;
        dispatch) service_sg="$dispatch_sg" ;;
        cart) service_sg="$cart_sg" ;;
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

    if [ "$instance" != "frontend" ]; then
        IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PrivateIpAddress' \
            --output text)
        r53_record="${instance}.${domain_name}."
    else
        IP=$(aws ec2 describe-instances \
            --instance-ids "$instance_id" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text)
        r53_record="${domain_name}"
    fi

    #update Route 53 record
    echo "Record: ${r53_record}"
    aws route53 change-resource-record-sets \
        --hosted-zone-id "$hosted_zone_id" \
        --change-batch '{
            "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                        "Name": "'"${r53_record}"'",
                        "Type": "A",
                        "TTL": 1,
                        "ResourceRecords": [
                            {
                                "Value": "'"${IP}"'"
                            }
                        ]
                    }
                }
            ]
        }'
done