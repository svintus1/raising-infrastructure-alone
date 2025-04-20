#!/bin/bash

USERNAME="$1"
PASSWORD="$2"

# Создание нового пользователя admin
sudo useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | sudo chpasswd
sudo usermod -aG sudo "$USERNAME"

sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Удаляем пароль для пользователя vagrant (оставляем только ключ)
sudo passwd -l vagrant
