#!/bin/bash

# Проверяем, запущен ли скрипт от root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "\033[31m[Ошибка]\033[0m Этот скрипт должен быть запущен от имени \033[1mroot\033[0m."
    exit 1
fi

# Устанавливаем необходимые пакеты для Ansible
echo -e "\033[32m==> Установка зависимостей...\033[0m"
apt install -y software-properties-common

# Добавляем репозиторий Ansible и устанавливаем его
echo -e "\033[32m==> Добавление репозитория Ansible...\033[0m"
add-apt-repository ppa:ansible/ansible -y
apt update
apt install -y ansible
echo -e "\033[32m✅ Ansible успешно установлен!\033[0m"

# Проверяем, существует ли уже SSH-ключ
SSH_KEY_PATH="$HOME/.ssh/id_rsa"
if [ -f "$SSH_KEY_PATH" ]; then
    echo -e "\033[33m[INFO]\033[0m SSH-ключ уже существует: \033[1m$SSH_KEY_PATH\033[0m"
else
    echo -e "\033[34m[INFO]\033[0m Создание SSH-ключа..."
    ssh-keygen -t rsa -b 4096 -C "ansible@$(hostname)" -f "$SSH_KEY_PATH" -N ""
fi

# Выводим публичный ключ
echo -e "\033[32m==> Публичный ключ:\033[0m"
cat "$SSH_KEY_PATH.pub"

echo -e "\033[33m[INFO]\033[0m Скопируйте публичный ключ на серверы (например, hosta и hostb)."
echo -e "\033[33m[INFO]\033[0m Пример: \033[1mssh-copy-id devops@<IP-адрес сервера>\033[0m"
echo -e "\033[32m[INFO]\033[0m После копирования нажмите любую кнопку для продолжения..."
read -n 1 -s -r

# Определяем IP-адреса серверов
echo -e "\033[32m==> Определение IP-адресов серверов...\033[0m"
hosta_ip=$(getent hosts hosta | awk '{ print $1 }')
hostb_ip=$(getent hosts hostb | awk '{ print $1 }')

if [ -z "$hosta_ip" ]; then
    echo -n -e "\033[34mВведите IP-адрес сервера A (hosta): \033[0m"
    read hosta_ip
fi
if [ -z "$hostb_ip" ]; then
    echo -n -e "\033[34mВведите IP-адрес сервера B (hostb): \033[0m"
    read hostb_ip
fi

# Формируем inventory.ini
servers="[all]\nhosta ansible_host=$hosta_ip ansible_ssh_user=devops\nhostb ansible_host=$hostb_ip ansible_ssh_user=devops\n"

# Получаем список всех пользователей из /home
for user in $(ls /home); do
    ansible_dir="/home/$user/ansible"
    
    mkdir -p "$ansible_dir"

    # Создаем файл inventory.ini
    echo -e "$servers" > "$ansible_dir/inventory.ini"

    # Создаем playbook.yml
    cat > "$ansible_dir/playbook.yml" <<'EOL'
- name: Configure Servers
  hosts:
    - hosta
    - hostb
  become: true
  vars:
    hosta_ip: "{{ hostvars['hosta']['ansible_host'] }}"
    hostb_ip: "{{ hostvars['hostb']['ansible_host'] }}"

  tasks:
    # Установка и настройка fail2ban на hosta
    - name: Install fail2ban on hosta
      apt:
        name: fail2ban
        state: present
      when: inventory_hostname == 'hosta'

    - name: Configure fail2ban on hosta
      copy:
        dest: /etc/fail2ban/jail.local
        content: |
          [DEFAULT]
          bantime  = 3600
          findtime  = 60
          maxretry = 3
          [sshd]
          enabled  = true
      notify: Restart fail2ban
      when: inventory_hostname == 'hosta'

    - name: Ensure fail2ban is running on hosta
      service:
        name: fail2ban
        state: started
        enabled: true
      when: inventory_hostname == 'hosta'

    # Установка и настройка PostgreSQL на hosta
    - name: Install PostgreSQL 16 on hosta
      apt:
        name:
          - postgresql
          - postgresql-contrib
        state: present
      when: inventory_hostname == 'hosta'

    - name: Start and enable PostgreSQL service on hosta
      service:
        name: postgresql
        state: started
        enabled: true
      when: inventory_hostname == 'hosta'

    - name: Create PostgreSQL users and databases on hosta
      shell: |
        sudo -u postgres psql <<SQL
        CREATE USER app WITH ENCRYPTED PASSWORD 'app';
        CREATE USER custom WITH ENCRYPTED PASSWORD 'custom';
        CREATE USER service WITH ENCRYPTED PASSWORD 'service';

        CREATE DATABASE app OWNER app;
        CREATE DATABASE custom OWNER custom;

        GRANT ALL PRIVILEGES ON DATABASE app TO app;
        GRANT ALL PRIVILEGES ON DATABASE custom TO custom;

        GRANT CONNECT ON DATABASE app TO service;
        GRANT CONNECT ON DATABASE custom TO service;

        \c app
        GRANT USAGE ON SCHEMA public TO service;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO service;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO service;

        \c custom
        GRANT USAGE ON SCHEMA public TO service;
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO service;
        ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO service;
        SQL
      when: inventory_hostname == 'hosta'

    # Разрешить подключение к PostgreSQL только с hostb
    - name: Restrict PostgreSQL access to hostb
      lineinfile:
        path: /etc/postgresql/16/main/pg_hba.conf
        line: "host    all             all             {{ hostb_ip }}/32            md5"
      notify: Restart postgresql
      when: inventory_hostname == 'hosta'

    - name: Allow PostgreSQL to listen on all interfaces
      lineinfile:
        path: /etc/postgresql/16/main/postgresql.conf
        regexp: "^#?listen_addresses ="
        line: "listen_addresses = '*'"
      notify: Restart postgresql
      when: inventory_hostname == 'hosta'

    # Установка и настройка nginx на hostb
    - name: Install nginx on hostb
      apt:
        name: nginx
        state: present
      when: inventory_hostname == 'hostb'

    - name: Configure nginx to proxy renue.ru on hostb
      copy:
        dest: /etc/nginx/sites-available/default
        content: |
          server {
              listen 80;
              server_name localhost;

              location / {
                  proxy_pass https://renue.ru;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }
          }
      notify: Restart nginx
      when: inventory_hostname == 'hostb'

    - name: Start and enable nginx service on hostb
      service:
        name: nginx
        state: started
        enabled: true
      when: inventory_hostname == 'hostb'

    # Закрытие доступа к nginx на hostb с hosta
    - name: Block access to nginx on hostb from hosta
      iptables:
        chain: INPUT
        protocol: tcp
        source: "{{ hosta_ip }}"
        destination_port: 80
        jump: DROP
      when: inventory_hostname == 'hostb'

    # Настройка резервного копирования PostgreSQL с hosta на hostb
    - name: Install rsync on hosta
      apt:
        name: rsync
        state: present
      when: inventory_hostname == 'hosta'

    - name: Configure PostgreSQL backup from hosta to hostb
      cron:
        name: "PostgreSQL Backup"
        minute: "0"
        hour: "3"
        job: "pg_dumpall -U postgres | gzip > /var/backups/postgresql_backup.sql.gz && rsync -avz /var/backups/postgresql_backup.sql.gz {{ hostb_ip }}:/var/backups/"
      when: inventory_hostname == 'hosta'

  handlers:
    - name: Restart fail2ban
      service:
        name: fail2ban
        state: restarted

    - name: Restart postgresql
      service:
        name: postgresql
        state: restarted

    - name: Restart nginx
      service:
        name: nginx
        state: restarted

EOL
done

# Отключаем проверку SSH-ключей для Ansible
export ANSIBLE_HOST_KEY_CHECKING=False

# Запуск Ansible Playbook эту хуйню на playbooke делать 2 раза
for i in {1..1}; do
    for user in $(ls /home); do
        ansible_dir="/home/$user/ansible"
        
        if [[ -f "$ansible_dir/inventory.ini" && -f "$ansible_dir/playbook.yml" ]]; then
            echo "Запуск playbook для пользователя $user (попытка $i)..."
            ansible-playbook -i "$ansible_dir/inventory.ini" "$ansible_dir/playbook.yml"
        else
            echo "Ansible файлы не найдены для пользователя $user, пропускаем..."
        fi
    done
done
