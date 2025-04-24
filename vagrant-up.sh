#!/bin/bash
set -e
clear

# Определение цветов
red="\x1b[31m"
green="\x1b[32m"
white="\x1b[37m"
purple="\u001b[35m"
bold="\e[1m"
italic="\033[3m"
red_bold=$red$bold
green_bold=$green$bold
white_bold=$white$bold
purple_bold=$purple$bold
reset="\e[0m"
checkmark="\xE2\x9C\x94"
cross="\xE2\x9C\x96"

install_vagrant() {
    # Объявленние переменных, необходимых для установки Vagrant
    KEY_URL="https://apt.releases.hashicorp.com/gpg"
    KEY_PATH="/usr/share/keyrings/hashicorp-archive-keyring.gpg"

    # Обновление HashiCorp GPG ключа
    echo -e "${white_bold}${italic}Обновляю HashiCorp GPG ключ...${reset}"
    wget -qO - "$KEY_URL" | gpg --batch --yes --dearmor -o "$KEY_PATH" \
    && echo -e "${green_bold}Ключ успешно обновлен${reset}" \
    || echo -e "${red_bold}Ошибка при обновлении ключа!${reset}"
    sleep 3
    clear

    # Установка Vagrant
    echo -e "${white_bold}${italic}Устанавливаю Vagrant...${reset}"
    echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=$KEY_PATH] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list
    if apt update && apt install -y vagrant; then
        echo -e "${green_bold}Vagrnt успешно установлен.${reset}"
        sleep 3 
        clear
    else
        echo -e "${red_bold}Ошибка при установке Vagrant!${reset}"
        exit 1
    fi
}

check_package() {
    dpkg -s "$1" 2>/dev/null | grep -q "Status: install ok installed"
}

get_valid_count() {
    local prompt="$1"
    local result_var="$2"
    local input=""

    while true; do
        echo -ne "${white_bold}${italic}${prompt}${reset}"
        read input
        if echo "$input" | grep -Eq "^[1-9]$"; then
            eval "$result_var=$input"
            break
        else
            echo -e "${red_bold}${italic}Неправильное значение! Введите число от 1 до 9${reset}"
        fi
    done
}

# Функция для проверки строки
check_input() {
    if [[ "$1" =~ ^[a-zA-Z0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

get_valid_name() {
    local prompt="$1"
    local result_var="$2"
    local input=""

    while true; do
        echo -ne "${white_bold}${italic}${prompt}${reset}"
        read input
        if check_input "$input"; then
            eval "$result_var=$input"
            break
        else
            echo -e "${red_bold}${italic}Ввод должен содержать только латинские буквы и цифры от 0 до 9!${reset}"
        fi
    done
}

# Проверка, запущен ли скрипт от root (UID 0)
if [[ "$EUID" -ne 0 ]]; then
    echo -e "${red_bold}Пожалуйста, запускайте этот скрипт с sudo или от имени пользователя root!${reset}" >&2
    exit 1
fi

cat <<'EOF'
                     $$\            $$\                           $$\   
                     \__|           $$ |                        $$$$ |  
 $$$$$$$\ $$\    $$\ $$\ $$$$$$$\ $$$$$$\   $$\   $$\  $$$$$$$\ \_$$ |  
$$  _____|\$$\  $$  |$$ |$$  __$$\\_$$  _|  $$ |  $$ |$$  _____|  $$ |  
\$$$$$$\   \$$\$$  / $$ |$$ |  $$ | $$ |    $$ |  $$ |\$$$$$$\    $$ |  
 \____$$\   \$$$  /  $$ |$$ |  $$ | $$ |$$\ $$ |  $$ | \____$$\   $$ |  
$$$$$$$  |   \$  /   $$ |$$ |  $$ | \$$$$  |\$$$$$$  |$$$$$$$  |$$$$$$\ 
\_______/     \_/    \__|\__|  \__|  \____/  \______/ \_______/ \______|
EOF

echo -e $'\n'"${red_bold}Для корректной работы скрипта необходмо использовать VPN${reset}"
echo -e $'\n'"${white_bold}${italic}Нажмите Enter, чтобы продолжить..."

# Ожидание нажатия клавиши Enter
read -r

# Проверка установки
for package in virtualbox virtualbox-ext-pack vagrant; do
    if ! check_package "$package"; then
        echo -e "${red_bold}${cross}  $package не установлен!${reset}"
        sleep 3
        clear
        if [[ "$package" == "vagrant" ]]; then
            install_vagrant
        else
            echo -e "${white_bold}${italic}Устанавливаю $package...${reset}"
            if apt install -y "$package"; then
                echo -e "${green_bold}$package успешно установлен${reset}"
                sleep 3 
                clear
            else
                echo -e "${red_bold}Ошибка при установке ${package}!${reset}"
                exit 1
            fi
        fi
    else
        echo -e "${green_bold}${checkmark}  $package уже установлен${reset}"
    fi
    sleep 3
done
clear

# Создание директории для проекта Vagrant
mkdir -p /root/vagrant
chmod 755 ./provision.sh
cp ./provision.sh /root/vagrant/
cd /root/vagrant

# Интерактивный ввод конфигураций сервера

echo -e "${purple_bold}Введите данные администратора для всех серверов${reset}"
get_valid_name "Логин: " username

is_equal=1
while [ $is_equal -ne 0 ]; do
    echo -ne "${white_bold}${italic}Пароль: ${reset}"
    read -s password1
    echo
    echo -ne "${white_bold}${italic}Повторите пароль: ${reset}"
    read -s password2
    echo
    if [[ "$password1" == "$password2" ]]; then
        password="$password1"
        is_equal=0
    else
        echo -e "${red_bold}Пароли не совпадают. Попробуйте снова!${reset}"
    fi
done

sleep 1
clear

echo -e "${purple_bold}Конфигурация среды production${reset}"
get_valid_count "Введите количество машин в кластере (1-9): " count_prod
get_valid_name "Введите название внутренней сети VirtualBox: " net_prod
sleep 1
clear

echo -e "${purple_bold}Конфигурация среды development${reset}"
get_valid_count "Введите количество машин в кластере (1-9): " count_dev
get_valid_name "Введите название внутренней сети VirtualBox: " net_dev

sleep 1
clear

echo -e "${purple_bold}Конфигурация вспомогательных серверов${reset}"
get_valid_count "Введите количество машин в кластере (1-9): " count_service
get_valid_name "Введите название внутренней сети VirtualBox: " net_service

sleep 1
clear

# Создание Vagrantfile
cat > Vagrantfile << EOF
username = ENV['VAGRANT_ADMIN_USER'] || 'admin'
password = ENV['VAGRANT_ADMIN_PASS'] || 'admin'

Vagrant.configure("2") do |config|
    config.vm.box = "debian/bookworm64"
    config.vm.box_version = "12.20250126.1"

    # Общие настройки SSH (для пользователя vagrant)
    config.ssh.insert_key = true  # Генерировать новый ключ
    (1..$count_prod).each do |i|
        config.vm.define "prod-#{i}" do |vm|
            vm.vm.hostname = "prod-node-#{i}"
            vm.ssh.host = "localhost"
            vm.ssh.username = "vagrant"
            vm.ssh.port = "221#{i}"

            # Проброс порта: 2222 → 22 (для подключения по ssh)
            vm.vm.network "forwarded_port",
                guest: 22,
                host: 2210 + i,
                id: "ssh",
                auto_correct: false

            # Внутренняя сеть
            vm.vm.network "private_network",
                type: "dhcp",
                virtualbox__intnet: "$net_prod"

            # Настройки VirtualBox
            vm.vm.provider "virtualbox" do |vb|
                vb.name = "debian-server-prod-#{i}"
                vb.memory = 1024
                vb.cpus = 1
        end

        vm.vm.provision "shell",
            path: "provision.sh",
            args: [username, password]
        end
    end
    (1..$count_dev).each do |i|
        config.vm.define "dev-#{i}" do |vm|
            vm.vm.hostname = "dev-node-#{i}"
            vm.ssh.host = "localhost"
            vm.ssh.username = "vagrant"
            vm.ssh.port = "222#{i}"

            # Проброс порта для подключения по ssh
            vm.vm.network "forwarded_port", 
                guest: 22,
                host: 2220 + i,
                id: "ssh",
                auto_correct: false

            # Внутренняя сеть
            vm.vm.network "private_network",
                type: "dhcp",
                virtualbox__intnet: "$net_dev"

            # Настройки VirtualBox
            vm.vm.provider "virtualbox" do |vb|
                vb.name = "debian-server-dev-#{i}"
                vb.memory = 1024
                vb.cpus = 1
        end

        vm.vm.provision "shell",
            path: "provision.sh",
            args: [username, password]
        end
    end
    (1..$count_service).each do |i|
        config.vm.define "service-#{i}" do |vm|
            vm.vm.hostname = "service-#{i}"
            vm.ssh.host = "localhost"
            vm.ssh.username = "vagrant"
            vm.ssh.port = "223#{i}"

            # Проброс порта для подключения по ssh
            vm.vm.network "forwarded_port", 
                guest: 22,
                host: 2230 + i,
                id: "ssh",
                auto_correct: false

            # Внутренняя сеть
            vm.vm.network "private_network",
                type: "dhcp",
                virtualbox__intnet: "$net_service"

            # Настройки VirtualBox
            vm.vm.provider "virtualbox" do |vb|
                vb.name = "debian-server-service-#{i}"
                vb.memory = 2048
                vb.cpus = 1
        end

        vm.vm.provision "shell",
            path: "provision.sh",
            args: [username, password]
        end
    end
end
EOF

# Запуск Vagrant
if VAGRANT_ADMIN_USER=$username VAGRANT_ADMIN_PASS=$password vagrant up; then
    echo -e "${green_bold}Виртуальные машины успешно созданы${reset}"
else
    echo -e "${red_bold}Ошибка при создании виртуальных машин!${reset}"
fi

# Выключаем VM
for i in prod dev service; do
    count_var="count_$i"  
    count=${!count_var}
    
    for ((j=1; j<=count; j++)); do
        vboxmanage controlvm "debian-server-$i-$j" acpipowerbutton
    done
done

# Ждем пока VM выключится
for i in prod dev service; do
    count_var="count_$i"  
    count=${!count_var}
    
    for ((j=1; j<=count; j++)); do
        while [ "$(vboxmanage showvminfo "debian-server-$i-$j" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
            sleep 5
        done
    done
done

# Отключение ненужных адаптеров у VM
for i in prod dev service; do
    count_var="count_$i"  
    count=${!count_var}
    
    for ((j=1; j<=count; j++)); do
        vboxmanage modifyvm "debian-server-$i-$j" --nic1 none
    done
done

# Запуск VM
for i in prod dev service; do
    count_var="count_$i"  
    count=${!count_var}
    
    for ((j=1; j<=count; j++)); do
        vboxmanage startvm "debian-server-$i-$j" --type headless
    done
done

sleep 3
clear

echo -e "${green_bold}Скрипт отработал на 5+${reset}"
