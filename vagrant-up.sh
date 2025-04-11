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
echo -e "\e[1m\e[35mВведите данные для конфигурации production сервера\e[0m"
echo -ne "\e[3mИмя сервера: \e[0m"
read hostname1
echo -ne "\e[3mИмя сервера в VirtualBox: \e[0m"
read vboxservername1
echo -ne "\e[3mИмя администратора: \e[0m"
read username1
echo -ne "\e[3mПароль администратора: \e[0m"
read -s password1
clear
echo -e "\e[1m\e[35mВведите данные для конфигурации staging сервера\e[0m"
echo -ne "\e[3mИмя сервера: \e[0m"
read hostname2
echo -ne "\e[3mИмя сервера в VirtualBox: \e[0m"
read vboxservername2
echo -ne "\e[3mИмя администратора: \e[0m"
read username2
echo -ne "\e[3mПароль администратора: \e[0m"
read -s password2
clear

# Создание Vagrantfile
cat > Vagrantfile << EOF
Vagrant.configure("2") do |config|
    config.vm.box = "generic/ubuntu2204"
    
    # Общие настройки SSH (для пользователя vagrant)
    config.ssh.insert_key = true  # Генерировать новый ключ

    config.vm.boot_timeout = 600

    # Первая VM - server1
    config.vm.define "vm1" do |vm1|
      vm1.vm.hostname = "$hostname1"
      vm1.ssh.host = "localhost"
      vm1.ssh.username = "vagrant"
      vm1.ssh.port = "2222"

      # Проброс порта: 2222 → 22 (для подключения по ssh)
      vm1.vm.network "forwarded_port", 
        guest: 22,
        host: 2222,
        id: "ssh",
        auto_correct: false
      
      # Внутренняя сеть
      vm1.vm.network "private_network",
          type: "dhcp",                  # Используем DHCP вместо статики
          virtualbox__intnet: "intnet100"
      
      # Настройки VirtualBox
      vm1.vm.provider "virtualbox" do |vb|
        vb.name = "$vboxservername1"
        vb.memory = 2048
        vb.cpus = 1
      end
  
      # Создание пользователя admin с паролем
      vm1.vm.provision "shell", inline: <<-SHELL
        # Обновление sshd
	      sudo apt update
	      sudo apt-get install --only-upgrade openssh-server -y
	      sudo systemctl enable sshd
        # Создание нового пользователя admin
	      sudo useradd -m -s /bin/bash $username1
        echo "$username1:$password1" | sudo chpasswd
        sudo usermod -aG sudo $username1
  
        # Разрешаем парольный SSH только для admin
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo passwd -d vagrant
  
        # Удаляем пароль для пользователя vagrant (оставляем только ключ)
        sudo passwd -d vagrant
      SHELL
    end
  
    # Вторая VM - server2 (аналогично)
    config.vm.define "vm2" do |vm2|
      vm2.vm.hostname = "$hostname2"
      vm2.ssh.host = "localhost"
      vm2.ssh.username = "vagrant"
      vm2.ssh.port = "2223"

      # Проброс порта: 2222 → 22 (для ручного подключения)
      vm2.vm.network "forwarded_port", 
        guest: 22,
        host: 2223,
        id: "ssh",
        auto_correct: false
    
        # Внутренняя сеть
      vm2.vm.network "private_network",
          type: "dhcp",                  # Используем DHCP вместо статики
          virtualbox__intnet: "intnet200"
      
      vm2.vm.provider "virtualbox" do |vb|
        vb.name = "$vboxservername2"
        vb.memory = 2048
        vb.cpus = 1
      end
  
      vm2.vm.provision "shell", inline: <<-SHELL
	      sudo apt update
	      sudo apt-get install --only-upgrade openssh-server -y
	      sudo systemctl enable sshd
	      sudo useradd -m -s /bin/bash $username2
        echo "$username2:$password2" | sudo chpasswd
        sudo usermod -aG sudo $username2
        sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
        sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo passwd -d vagrant
      SHELL
    end
end
EOF

# Запуск Vagrant
vagrant up && echo -e "\e[32m\e[1mВиртуальные машины успешно созданы.\e[0m" \
|| echo -e "\e[31m\e[1mОшибка при создании виртуальных машин!\e[0m"

# Выключение VM
sudo vboxmanage controlvm "$vboxservername1" acpipowerbutton
sudo vboxmanage controlvm "$vboxservername2" acpipowerbutton

# Ждем пока VM выключится
while [ "$(sudo vboxmanage showvminfo "$vboxservername1" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
    sleep 5
done

while [ "$(sudo vboxmanage showvminfo "$vboxservername2" --machinereadable | grep 'VMState=')" != 'VMState="poweroff"' ]; do
    sleep 5
done

# Отключение ненужных адаптеров у VM 
sudo vboxmanage modifyvm "$vboxservername1" --nic1 none
sudo vboxmanage modifyvm "$vboxservername2" --nic1 none

sleep 2

# Запуск VM
sudo vboxmanage startvm "$vboxservername1" --type headless
sudo vboxmanage startvm "$vboxservername2" --type headless

sleep 5

clear