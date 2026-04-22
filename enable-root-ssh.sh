#!/usr/bin/env bash
set -e

SSHD_CONFIG='/etc/ssh/sshd_config'

if [ "$(id -u)" -ne 0 ]; then
  echo "请使用 root 执行，或先运行 sudo -i"
  exit 1
fi

read -rsp "请输入新的 root 密码: " ROOT_PASSWORD
echo

echo "[1/5] 设置 root 密码..."
echo "root:${ROOT_PASSWORD}" | chpasswd
unset ROOT_PASSWORD

echo "[2/5] 备份 sshd_config..."
cp -a "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%F-%H%M%S)"

echo "[3/5] 开启 PermitRootLogin yes..."
if grep -Eq '^[#[:space:]]*PermitRootLogin' "${SSHD_CONFIG}"; then
  sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin yes/' "${SSHD_CONFIG}"
else
  echo 'PermitRootLogin yes' >> "${SSHD_CONFIG}"
fi

echo "[4/5] 开启 PasswordAuthentication yes..."
if grep -Eq '^[#[:space:]]*PasswordAuthentication' "${SSHD_CONFIG}"; then
  sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication yes/' "${SSHD_CONFIG}"
else
  echo 'PasswordAuthentication yes' >> "${SSHD_CONFIG}"
fi

echo "[5/5] 检查 sshd 配置并重启服务..."
sshd -t

if command -v systemctl >/dev/null 2>&1; then
  systemctl restart sshd || systemctl restart ssh
else
  service sshd restart || service ssh restart
fi

echo "完成，请新开窗口测试 root 登录。"