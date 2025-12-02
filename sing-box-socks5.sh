#!/bin/bash

# --- 辅助函数：生成随机字符串 ---
generate_random_string() {
  tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$1"
}

# --- 辅助函数：检测端口是否被占用 ---
check_port() {
  local port=$1
  if command -v ss >/dev/null 2>&1; then
    ss -tuln | grep -q ":$port "
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | grep -q ":$port "
  elif command -v lsof >/dev/null 2>&1; then
    lsof -i :$port >/dev/null 2>&1
  else
    # 无法检测时默认端口可用
    return 1
  fi
}

# --- 1. 安装 Sing-Box ---
echo ">>> 正在检查并安装 sing-box..."

if ! command -v sing-box >/dev/null 2>&1; then
    download_beta=false
    download_version=""
    
    while [ $# -gt 0 ]; do
      case "$1" in
        --beta) download_beta=true; shift ;;
        --version) shift; download_version="$1"; shift ;;
        *) shift ;;
      esac
    done

    if command -v pacman >/dev/null 2>&1; then
      os="linux"; arch=$(uname -m); package_suffix=".pkg.tar.zst"; package_install="pacman -U --noconfirm"
    elif command -v dpkg >/dev/null 2>&1; then
      os="linux"; arch=$(dpkg --print-architecture); package_suffix=".deb"; package_install="dpkg -i"
    elif command -v dnf >/dev/null 2>&1; then
      os="linux"; arch=$(uname -m); package_suffix=".rpm"; package_install="dnf install -y"
    elif command -v rpm >/dev/null 2>&1; then
      os="linux"; arch=$(uname -m); package_suffix=".rpm"; package_install="rpm -i"
    else
      echo "错误: 未找到支持的包管理器。"
      exit 1
    fi

    if [ -z "$download_version" ]; then
      if [ "$download_beta" != "true" ]; then
        latest_release=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest)
      else
        latest_release=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases)
      fi
      download_version=$(echo "$latest_release" | grep tag_name | head -n 1 | awk -F: '{print $2}' | sed 's/[", v]//g')
    fi

    if [ -z "$download_version" ]; then
        echo "错误: 无法获取下载版本。"
        exit 1
    fi

    package_name="sing-box_${download_version}_${os}_${arch}${package_suffix}"
    package_url="https://github.com/SagerNet/sing-box/releases/download/v${download_version}/${package_name}"

    echo "正在下载: $package_url"
    curl --fail -Lo "$package_name" "$package_url"
    if [ $? -ne 0 ]; then
      echo "下载失败。"
      exit 1
    fi

    echo "正在安装..."
    if command -v sudo >/dev/null 2>&1; then
      sudo $package_install "$package_name"
    else
      $package_install "$package_name"
    fi
    rm -f "$package_name"
else
    echo "sing-box 已安装，跳过安装步骤。"
fi

# --- 2. 生成随机端口 (50000-60000) ---
# 注意：我们将端口生成提前，因为文件名需要用到端口号
echo ">>> 正在分配端口..."
MAX_RETRIES=10
found_port=false

for ((i=1; i<=MAX_RETRIES; i++)); do
  RAND_PORT=$((RANDOM % 10001 + 50000))
  if check_port "$RAND_PORT"; then
    echo "端口 $RAND_PORT 被占用，正在重试..."
  else
    SOCKS_PORT=$RAND_PORT
    found_port=true
    break
  fi
done

if [ "$found_port" = false ]; then
  echo "错误: 无法在 10 次尝试中找到空闲端口。"
  exit 1
fi

# --- 3. 定义动态文件路径 ---
# 配置文件名现在包含实际端口号，例如: socks5-54321.conf
CONF_DIR="/etc/sing-box/conf"
CONF_FILE="$CONF_DIR/socks5-${SOCKS_PORT}.conf"
mkdir -p "$CONF_DIR"

# 服务名也包含端口号，例如: sing-box-socks5-54321
SERVICE_NAME="sing-box-socks5-${SOCKS_PORT}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# --- 4. 生成随机用户名和密码 ---
SOCKS_USER=$(generate_random_string 8)
SOCKS_PASS=$(generate_random_string 16)

echo ">>> 生成凭证:"
echo "端口: $SOCKS_PORT"
echo "用户: $SOCKS_USER"
echo "密码: $SOCKS_PASS"

# --- 5. 写入配置文件 ---
cat > "$CONF_FILE" <<EOF
{
  "log": {
    "level": "info"
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": $SOCKS_PORT,
      "users": [
        {
          "username": "$SOCKS_USER",
          "password": "$SOCKS_PASS"
        }
      ]
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "inbound": [
          "socks-in"
        ],
        "outbound": "direct"
      }
    ]
  }
}
EOF

echo ">>> 配置文件已写入: $CONF_FILE"

# --- 6. 创建 Systemd 服务 ---
BINARY_PATH=$(command -v sing-box)
if [ -z "$BINARY_PATH" ]; then
    echo "错误: 找不到 sing-box 可执行文件路径。"
    exit 1
fi

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sing-Box SOCKS5 Service (Port ${SOCKS_PORT})
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
Type=simple
User=root
Group=root
ExecStart=$BINARY_PATH run -c $CONF_FILE
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

echo ">>> Systemd 服务文件已创建: $SERVICE_FILE"

# --- 7. 启动服务 ---
echo ">>> 正在启动服务: $SERVICE_NAME"
systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# --- 8. 检查运行状态 ---
sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo ""
    echo "=========================================="
    echo "   Sing-Box SOCKS5 安装配置成功！"
    echo "=========================================="
    echo " 服务名称 : $SERVICE_NAME"
    echo " 配置文件 : $CONF_FILE"
    echo "------------------------------------------"
    echo " IP 地址  : (本机IP)"
    echo " 端口     : $SOCKS_PORT"
    echo " 用户名   : $SOCKS_USER"
    echo " 密码     : $SOCKS_PASS"
    echo "=========================================="
else
    echo "错误: 服务启动失败，请使用 journalctl -u $SERVICE_NAME -xe 查看日志。"
    exit 1
fi
