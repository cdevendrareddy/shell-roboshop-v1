#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/shell-practice"
logs_file="${logs_folder}/${0}.log"
domain_name="opsbydev.online"
scripts_dir=$(dirname "$(realpath "$0")")
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ $user_id -ne 0 ]; then
    echo "Please run this script with sudo access.."
    exit 1
fi

mkdir -p $logs_folder

timestamp(){
    date +"%F %T"
}


validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}..${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else
        echo -e "$(timestamp) [INFO] ${2}..${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

echo "$(timestamp) [INFO] === Script started execution ===" | tee -a $logs_file

dnf module disable nodejs -y &>> $logs_file
dnf module enable nodejs:24 -y &>> $logs_file
dnf install nodejs -y &>> $logs_file
validate $? "Installing NodeJS"


id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
    validate $? "Creating roboshop user"
else
    echo -e "$(timestamp) [INFO] roboshop user already exists,${Y}skipping user creation${N}"
fi

rm -rf /app
mkdir -p /app
validate $? "Creating /app directory"

curl -L -o /tmp/catalogue.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/catalogue-v4.zip &>> $logs_file
validate $? "Downloading catalogue application zip file"

cd /app
unzip /tmp/catalogue.zip &>> $logs_file
validate $? "Extracting catalogue application"

cd /app
npm install &>> $logs_file
validate $? "Installing catalogue application dependencies"

sed -i "s/DOMAIN_NAME/${domain_name}/" "$scripts_dir/catalogue.service"
cp "$scripts_dir/catalogue.service" /etc/systemd/system/catalogue.service

systemctl daemon-reload &>> $logs_file
systemctl enable catalogue &>> $logs_file
systemctl start catalogue &>> $logs_file
validate $? "Starting catalogue service"

cp "$scripts_dir/mongo.repo" /etc/yum.repos.d/mongo.repo
validate $? "Adding MongoDB repo"

dnf install mongodb-mongosh -y &>> $logs_file
validate $? "Installing MongoDB shell"

product_count=$(mongosh --host <MONGODB-SERVER-IPADDRESS> --quiet --eval 'db.getSiblingDB("catalogue").products.countDocuments()') 2>>$logs_file
validate $? "Checking product count in MongoDB"

if [ $product_count -eq 0]; then
    mongosh --host <MONGODB-SERVER-IPADDRESS> </app/db/master-data.js
    validate $? "Loading master data into MongoDB"
else 
    echo -e "$(timestamp) [INFO] Master data already exists in MongoDB, ${Y}skipping master data load${N}"
fi

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] === Script completed execution ===" | tee -a $logs_file