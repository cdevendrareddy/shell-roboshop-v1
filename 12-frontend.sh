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

dnf module disable nginx -y &>> $logs_file
dnf module enable nginx:1.26 -y &>> $logs_file
dnf install nginx -y &>> $logs_file
validate $? "Installing Nginx"

systemctl enable nginx
systemctl start nginx
validate $? "Starting and enabling Nginx service"

rm -rf /usr/share/nginx/html/*
validate $? "Cleaning Nginx default content"

curl -L -o /tmp/frontend.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/frontend-v4.zip
validate $? "Downloading frontend application zip file"

cd /usr/share/nginx/html
validate $? "Changing directory to Nginx html folder"

unzip /tmp/frontend.zip
validate $? "Extracting frontend application"

sed -i "s/DOMAIN_NAME/$domain_name/g" "$scripts_dir/roboshop.conf"
cp "$scripts_dir/roboshop.conf" /etc/nginx/default.d/roboshop.conf
validate $? "Copying Nginx configuration file"

nginx -t
validate $? "Testing Nginx configuration"
systemctl restart nginx
validate $? "Restarting Nginx service"

sleep 10

curl http://localhost:8080/health
validate $? "Checking frontend service health"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] === Script completed execution ===" | tee -a $logs_file