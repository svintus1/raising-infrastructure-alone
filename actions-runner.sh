#!/bin/bash
set -e

cd ansible

read -p "Введите токен для server-staging: " runner_token
ansible-playbook -i inventory/hosts.ini all.yml \
  --tags actions-runner \
  --limit server-staging \
  -e "runner_token=${runner_token}"

read -p "Введите токен для server-production: " v_token
ansible-playbook -i inventory/hosts.ini all.yml \
  --tags actions-runner \
  --limit server-production \
  -e "runner_token=${runner_token}"