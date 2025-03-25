#!/bin/bash

# Проверяем, запущен ли скрипт от root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m[Ошибка]\033[0m Этот скрипт должен быть запущен от имени \033[1mroot\033[0m."
    exit 1
fi

set -e  # Остановит выполнение при ошибке

echo -e "\033[32m==> Отключение SSH авторизации по паролю и настройка стабильного соединения...\033[0m"
sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#ClientAliveInterval.*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sudo sed -i 's/^#ClientAliveCountMax.*/ClientAliveCountMax 100/' /etc/ssh/sshd_config
sudo systemctl reload sshd
echo -e "\033[32m✅ Настройки SSH обновлены!\033[0m"

echo -e "\033[32m==> Создание пользователя devops...\033[0m"
sudo useradd -m devops
echo "devops:devops_password" | sudo chpasswd
echo "devops ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers > /dev/null
sudo usermod -aG sudo devops
echo -e "\033[32m✅ Пользователь devops успешно создан!\033[0m"

echo -e "\033[32m==> Введите публичный SSH ключ:\033[0m"
read -p "Введите публичный SSH ключ: " pubkey
sudo mkdir -p /home/devops/.ssh
echo "$pubkey" | sudo tee /home/devops/.ssh/authorized_keys > /dev/null
sudo chown -R devops:devops /home/devops/.ssh
sudo chmod 700 /home/devops/.ssh
sudo chmod 600 /home/devops/.ssh/authorized_keys
echo -e "\033[32m✅ SSH-ключ для devops настроен!\033[0m"

echo -e "\033[32m✅ Настройка завершена успешно!\033[0m"
