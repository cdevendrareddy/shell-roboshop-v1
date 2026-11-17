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

dnf module enable maven:3.9 -y &>> $logs_file
dnf install maven java-25-openjdk-devel -y &>> $logs_file
validate $? "Installing Maven and Java"

alternatives --set java /usr/lib/jvm/java-25-openjdk/bin/java &>> $logs_file
validate $? "Setting Java alternative"

echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))" > /etc/profile.d/java.sh
source /etc/profile.d/java.sh
echo $JAVA_HOME
validate $? "Setting JAVA_HOME for maven"

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

curl -L -o /tmp/shipping.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/shipping-v4.zip &>> $logs_file
validate $? "Downloading shipping application zip file"

cd /app
unzip /tmp/shipping.zip &>> $logs_file
validate $? "Extracting shipping application"

cd /app
mvn clean package &>> $logs_file
validate $? "Building shipping application"

mv target/shipping.jar shipping.jar
validate $? "Renaming shipping jar file"

sed -i "s/DOMAIN_NAME/${domain_name}/" "$scripts_dir/shipping.service"
cp "$scripts_dir/shipping.service" /etc/systemd/system/shipping.service

dnf install mysql -y &>> $logs_file
validate $? "Installing MySQL client"

count=$(mysql -h "mysql.$domain_name" -u root -pRoboShop@1 -N -B -e "SELECT COUNT(*) FROM cities.cities;" 2>> $logs_file )
if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    mysql -h "mysql.$domain_name" -uroot -pRoboShop@1 < /app/db/master-data.sql
    echo -e "$(timestamp) [INFO] Shipping database schema is not loaded,${Y}loading schema${N}"
else
    echo -e "$(timestamp) [INFO] Shipping database schema is already loaded,${Y}skipping schema load${N}"
fi


mysql -h mysql.${domain_name} -uroot -pRoboShop@1 < /app/db/app-user.sql
validate $? "Creating shipping database user and granting privileges"


systemctl daemon-reload &>> $logs_file
systemctl enable shipping &>> $logs_file
systemctl restart shipping
validate $? "Starting and enabling shipping service"


sleep 20

curl http://localhost:8080/actuator/health
validate $? "Checking shipping service health"

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] === Script completed execution ===" | tee -a $logs_file