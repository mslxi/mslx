#!/bin/bash

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 用户运行此脚本"
    exit 1
fi

# 设置用户名
read -p "请输入需要设置SSH密钥的用户名: " SSH_USER

# 检查用户是否存在
if ! id "$SSH_USER" &>/dev/null; then
    echo "用户 $SSH_USER 不存在"
    exit 1
fi

# 硬编码公钥
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJuWmoZzlxXE/BbCA1mQgibexikymy+jvcuziGSvi1mM d@ciii.club"

# 创建 .ssh 目录
USER_HOME=$(eval echo "~$SSH_USER")
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
chown "$SSH_USER":"$SSH_USER" "$SSH_DIR"

# 写入 authorized_keys
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
touch "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"
chown "$SSH_USER":"$SSH_USER" "$AUTHORIZED_KEYS"

# 避免重复写入
grep -qxF "$PUBKEY" "$AUTHORIZED_KEYS" || echo "$PUBKEY" >> "$AUTHORIZED_KEYS"

echo "SSH公钥已添加成功"

# 询问是否关闭密码登录
read -p "是否关闭SSH密码登录以只允许密钥登录? (Y/N): " CLOSE_PASS

if [[ "$CLOSE_PASS" =~ ^[Yy]$ ]]; then
    SSHD_CONFIG="/etc/ssh/sshd_config"

    # 备份原配置
    cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak_$(date +%F_%T)"

    # 设置PasswordAuthentication为no
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"

    # 重启SSH服务
    systemctl restart sshd
    echo "SSH服务已重启，密码登录已禁用"
else
    echo "保留密码登录"
fi

echo "操作完成"
