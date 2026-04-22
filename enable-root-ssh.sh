#!/usr/bin/env bash
set -euo pipefail

SSHD_CONFIG="/etc/ssh/sshd_config"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "请使用 root 执行，或先运行 sudo -i"
  exit 1
fi

if [[ ! -f "$SSHD_CONFIG" ]]; then
  echo "错误：找不到 SSH 配置文件：$SSHD_CONFIG"
  exit 1
fi

if ! command -v sshd >/dev/null 2>&1; then
  echo "错误：未找到 sshd 命令，请确认已安装 openssh-server"
  exit 1
fi

ROOT_PASSWORD="${1:-}"

if [[ -z "$ROOT_PASSWORD" ]]; then
  read -rsp "请输入新的 root 密码: " ROOT_PASSWORD
  echo
fi

if [[ -z "$ROOT_PASSWORD" ]]; then
  echo "错误：密码不能为空"
  exit 1
fi

backup_file="${SSHD_CONFIG}.bak.$(date +%F-%H%M%S)"

set_config() {
  local key="$1"
  local value="$2"

  if grep -Eq "^[#[:space:]]*${key}[[:space:]]+" "$SSHD_CONFIG"; then
    sed -i "s|^[#[:space:]]*${key}[[:space:]].*|${key} ${value}|g" "$SSHD_CONFIG"
  else
    echo "${key} ${value}" >> "$SSHD_CONFIG"
  fi
}

echo "[1/6] 设置 root 密码..."
echo "root:${ROOT_PASSWORD}" | chpasswd
unset ROOT_PASSWORD

echo "[2/6] 备份 sshd_config..."
cp -a "$SSHD_CONFIG" "$backup_file"
echo "备份文件：$backup_file"

echo "[3/6] 开启 PermitRootLogin yes..."
set_config "PermitRootLogin" "yes"

echo "[4/6] 开启 PasswordAuthentication yes..."
set_config "PasswordAuthentication" "yes"

echo "[5/6] 检查 sshd 配置..."
sshd -t

echo "[6/6] 重启 SSH 服务..."
if command -v systemctl >/dev/null 2>&1; then
  systemctl restart sshd 2>/dev/null || systemctl restart ssh
else
  service sshd restart 2>/dev/null || service ssh restart
fi

echo
echo "完成，请新开终端测试 root SSH 登录。"
echo "如果无法登录，可使用备份恢复配置："
echo "cp -a '$backup_file' '$SSHD_CONFIG'"
