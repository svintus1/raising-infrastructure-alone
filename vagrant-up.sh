#!/bin/bash
set -e

# Приветственное сообщение
echo -e "\e[31m\e[1m              ВНИМАНИЕ!!!\e[0m"
echo -e "\e[37m\e[1mДля работы данного скрипта необходим VPN.\e[0m"
echo -e "\e[37m\e[1mПроверьте подключение, прежде чем начать\e[0m"
echo -e "\e[37m\e[1mвыполнение. Также предполагается, что\e[0m"
echo -e "\e[37m\e[1mVirtualBox уже установлен на ваш ПК. Если\e[0m"
echo -e "\e[37m\e[1mусловия не выполнены, то прервите выполнение,\e[0m"
echo -e "\e[37m\e[1mнажав на клавиатуре \e[0m\e[31m\e[1m Ctrl + C\e[0m"$'\n'
read -p "Нажмите Enter для продолжения..."

clear
sleep 1

KEY_URL="https://apt.releases.hashicorp.com/gpg"
KEY_PATH="/usr/share/keyrings/hashicorp-archive-keyring.gpg"

echo -e "\e[37m\e[1mОбновление HashiCorp GPG ключа...\e[0m"
wget -qO - "$KEY_URL" | sudo gpg --batch --yes --dearmor -o "$KEY_PATH" \
&& echo -e "\e[32m\e[1mКлюч успешно обновлен.\e[0m" \
|| echo -e "\e[31m\e[1mОшибка при обновлении ключа!\e[0m"

sleep 3
clear

# Установка Vagrant
echo "deb [arch=$(dpkg --print-architecture) \
signed-by=$KEY_PATH] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant && clear \
&& echo -e "\e[32m\e[1mVagrnt успешно установлен.\e[0m"  && sleep 3 \
|| echo -e "\e[31m\e[1mОшибка при установке Vagrant!\e[0m" && sleep 3

clear

# Установка необходимых пакетов и запуск VirtualBox
sudo apt install virtualbox-ext-pack
sudo bash -c "virtualbox &"

clear

sleep 3

# Создание директории для проекта Vagrant
mkdir -p /home/root/vagrant
cd /home/root/vagrant

# Интерактивный ввод конфигураций сервера
echo -e "\e[1m\e[35mВведите данные для администратора\e[0m"
echo -ne "\e[3mИмя: \e[0m"
read username
echo -ne "\e[3mПароль: \e[0m"
read -s password
clear

# Создание Vagrantfile
cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
    (1..3).each do |i|
        config.vm.box = "generic/ubuntu2204"
        
        # Общие настройки SSH (для пользователя vagrant)
        config.ssh.insert_key = true  # Генерировать новый ключ

        config.vm.boot_timeout = 600

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
                vb.name = "ubuntu-server-#{i}"
                vb.memory = 2048
                vb.cpus = 1
        end
    
        # Создание пользователя admin с паролем
        vm.vm.provision "shell", inline: <<-SHELL
            # Обновление sshd
            sudo apt update
            sudo apt-get install --only-upgrade openssh-server -y
            sudo systemctl enable sshd

            # Создание нового пользователя admin
            sudo useradd -m -s /bin/bash $username
            echo "$username:$password" | sudo chpasswd
            sudo usermod -aG sudo $username
     
            # Удаляем пароль для пользователя vagrant (оставляем только ключ)
            sudo passwd -d vagrant
        SHELL
        end
    end
end
EOF

# Запуск Vagrant
vagrant up && echo -e "\e[32m\e[1mВиртуальные машины успешно созданы.\e[0m" \
|| echo -e "\e[31m\e[1mОшибка при создании виртуальных машин!\e[0m"

# Выключение VM
sudo vboxmanage controlvm "ubuntu-server-1" acpipowerbutton
sudo vboxmanage controlvm "ubuntu-server-2" acpipowerbutton
sudo vboxmanage controlvm "ubuntu-server-3" acpipowerbutton

# Ждем пока VM выключится
while [ "$(sudo vboxmanage showvminfo "ubuntu-server-1" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
    sleep 5
done

while [ "$(sudo vboxmanage showvminfo "ubuntu-server-2" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
    sleep 5
done

while [ "$(sudo vboxmanage showvminfo "ubuntu-server-3" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
    sleep 5
done

# Отключение ненужных адаптеров у VM 
sudo vboxmanage modifyvm "ubuntu-server-1" --nic1 none
sudo vboxmanage modifyvm "ubuntu-server-2" --nic1 none
sudo vboxmanage modifyvm "ubuntu-server-3" --nic1 none

sleep 2

# Запуск VM
sudo vboxmanage startvm "ubuntu-server-1" --type headless
sudo vboxmanage startvm "ubuntu-server-2" --type headless
sudo vboxmanage startvm "ubuntu-server-3" --type headless

sleep 5

clear