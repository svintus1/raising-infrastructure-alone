#!/bin/bash
set -e

install_vagrant() {
    # Объявленние переменных, необходимых для установки Vagrant
    KEY_URL="https://apt.releases.hashicorp.com/gpg"
    KEY_PATH="/usr/share/keyrings/hashicorp-archive-keyring.gpg"

    echo -e "Обновление HashiCorp GPG ключа..."
    wget -qO - "$KEY_URL" | gpg --batch --yes --dearmor -o "$KEY_PATH" \
    && echo -e "Ключ успешно обновлен." \
    || echo -e "Ошибка при обновлении ключа!"
    sleep 3
    clear

    # Установка Vagrant
    echo "deb [arch=$(dpkg --print-architecture) \
    signed-by=$KEY_PATH] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | tee /etc/apt/sources.list.d/hashicorp.list
    apt update && apt install vagrant \
    && echo -e "Vagrnt успешно установлен." \
    || echo -e "Ошибка при установке Vagrant!"
    sleep 3
    clear
}

check_package() {
    dpkg -s "$1" 2>/dev/null | grep -q "Status: install ok installed"
}

# Проверка установки
for package in virtualbox virtualbox-ext-pack vagrant; do
    if ! check_package "$package" && [[ "$package" == "vagrant" ]]; then
        echo "Устанавливаю vagrant..."
        install_vagrant
    elif ! check_package "$package"; then
        echo "Устанавливаю $package..."
        apt install -y "$package"
    else
        echo "$package уже установлен."
    fi
done
sleep 3
clear


# Создание директории для проекта Vagrant
mkdir -p /home/root/vagrant
chmod 755 ./provision.sh
cp ./provision.sh /home/root/vagrant/
cd /home/root/vagrant

# Интерактивный ввод конфигураций сервера
echo -e "Введите данные для администратора"
echo -ne "Имя: "
read username
echo -ne "Пароль: "
read -s password
clear

# Создание Vagrantfile
cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
    (1..5).each do |i|
        config.vm.box = "debian/bookworm64"
        config.vm.box_version = "12.20250126.1"

        # Общие настройки SSH (для пользователя vagrant)
        config.ssh.insert_key = true  # Генерировать новый ключ

        config.vm.define "vm#{i}" do |vm|
            vm.vm.hostname = "server#{i}"
            vm.ssh.host = "localhost"
            vm.ssh.username = "vagrant"
            vm.ssh.port = "222#{i}"

            # Проброс порта: 2222 → 22 (для подключения по ssh)
            vm.vm.network "forwarded_port", 
                guest: 22,
                host: 2220 + i,
                id: "ssh",
                auto_correct: false
            
            # Внутренняя сеть
            vm.vm.network "private_network",
                type: "dhcp",                  # Используем DHCP вместо статики
                virtualbox__intnet: "intnet#{i}00"
            
            # Настройки VirtualBox
            vm.vm.provider "virtualbox" do |vb|
                vb.name = "debian-server-#{i}"
                vb.memory = 2048
                vb.cpus = 1
        end

        # Создание пользователя admin с паролем
        vm.vm.provision "shell",
            path: "provision.sh",
            args: ["$username", "$password"]
        end
    end
end
EOF

# Запуск Vagrant
vagrant up \
&& echo -e "Виртуальные машины успешно созданы." \
|| echo -e "Ошибка при создании виртуальных машин!"

# Выключаем VM
for i in {1..5}; do
    vboxmanage controlvm "debian-server-$i" acpipowerbutton
done

# Ждем пока VM выключится
for i in {1..5}; do
    while [ "$(vboxmanage showvminfo "debian-server-$i" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
        sleep 5
    done
done

# Отключение ненужных адаптеров у VM
for i in {1..5}; do
    vboxmanage modifyvm "debian-server-$i" --nic1 none
done

# Запуск VM
for i in {1..5}; do
    vboxmanage startvm "debian-server-$i" --type headless
done

clear