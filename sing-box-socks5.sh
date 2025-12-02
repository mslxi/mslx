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
    return 1
  fi
}

# --- 辅助函数：卸载功能 ---
uninstall_socks5() {
  local port=$1
  local service_name="sing-box-socks5-${port}"
  local config_file="/etc/sing-box/conf/socks5-${port}.conf"
  local service_file="/etc/systemd/system/${service_name}.service"

  echo ">>> 正在执行卸载 (端口: $port)..."

  # 检查服务是否存在
  if systemctl list-units --full -all | grep -Fq "$service_name.service"; then
    echo "停止并禁用服务: $service_name"
    systemctl stop "$service_name"
    systemctl disable "$service_name"
    rm -f "$service_file"
    echo "服务文件已删除。"
    systemctl daemon-reload
  else
    echo "未找到服务: $service_name (可能已手动删除)"
  fi

  # 删除配置文件
  if [ -f "$config_file" ]; then
    rm -f "$config_file"
    echo "配置文件已删除: $config_file"
  else
    echo "未找到配置文件: $config_file"
  fi

  echo ">>> 卸载完成。"
}

# =========================================================
# 1. 参数解析 (优先处理卸载)
# =========================================================
download_beta=false
download_version=""

# 循环解析参数
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall)
      shift
      if [ -z "$1" ]; then
        echo "错误: --uninstall 需要指定端口号 (例如: --uninstall 55001)"
        exit 1
      fi
      uninstall_socks5 "$1"
      exit 0
      ;;
    --beta)
      download_beta=true
      shift
      ;;
    --version)
      shift
      download_version="$1"
      shift
      ;;
    *)
      # 未知参数忽略或根据需要处理
      shift
      ;;
  esac
done

# =========================================================
# 2. 安装 Sing-Box (如果不存在)
# =========================================================
echo ">>> 正在检查环境..."

if ! command -v sing-box >/dev/null 2>&1; then
    echo "sing-box 未安装，开始自动安装..."
    
    # 检测包管理器
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

    # 获取版本
    if [ -z "$download_version" ]; then
      if [ "$download_beta" != "true" ]; then
        latest_release=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest)
      else
        latest_release=$(curl -s https://api.github.com/repos/SagerNet/sing-box/releases)
      fi
      download_version=$(echo "$latest_release" | grep tag_name | head -n 1 | awk -F: '{print $2}' | sed 's/[", v]//g')
    fi

    if [ -z "$download_version" ]; then
        echo "错误: 无法获取 sing-box 版本信息。"
        exit 1
    fi

    package_name="sing-box_${download_version}_${os}_${arch}${package_suffix}"
    package_url="https://github.com/SagerNet/sing-box/releases/download/v${download_version}/${package_name}"

    echo "下载: $package_url"
    curl --fail -Lo "$package_name" "$package_url"
    if [ $? -ne 0 ]; then
      echo "下载失败。"
      exit 1
    fi

    if command -v sudo >/dev/null 2>&1; then
      sudo $package_install "$package_name"
    else
      $package_install "$package_name"
    fi
    rm -f "$package_name"
else
    echo "sing-box 已安装，跳过安装。"
fi

# =========================================================
# 3. 端口与凭证配置
# =========================================================
echo ">>> 正在分配资源..."

# 生成端口
MAX_RETRIES=10
found_port=false
for ((i=1; i<=MAX_RETRIES; i++)); do
  RAND_PORT=$((RANDOM % 10001 + 50000))
  if check_port "$RAND_PORT"; then
    : # 端口占用，重试
  else
    SOCKS_PORT=$RAND_PORT
    found_port=true
    break
  fi
done

if [ "$found_port" = false ]; then
  echo "错误: 无法分配空闲端口。"
  exit 1
fi

# 生成凭证
SOCKS_USER=$(generate_random_string 8)
SOCKS_PASS=$(generate_random_string 16)

# 定义路径
CONF_DIR="/etc/sing-box/conf"
CONF_FILE="$CONF_DIR/socks5-${SOCKS_PORT}.conf"
mkdir -p "$CONF_DIR"

SERVICE_NAME="sing-box-socks5-${SOCKS_PORT}"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# =========================================================
# 4. 写入配置 & 服务文件
# =========================================================
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
        "inbound": [ "socks-in" ],
        "outbound": "direct"
      }
    ]
  }
}
EOF

BINARY_PATH=$(command -v sing-box)
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sing-Box SOCKS5 Service (Port ${SOCKS_PORT})
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$BINARY_PATH run -c $CONF_FILE
Restart=on-failure
RestartSec=10s
LimitNOFILE=infinity
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

# =========================================================
# 5. 启动服务
# =========================================================
systemctl daemon-reload
systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
systemctl restart "$SERVICE_NAME"

sleep 2
if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "错误: 服务启动失败。"
    exit 1
fi

# =========================================================
# 6. 获取 IP 并输出信息
# =========================================================
echo ">>> 正在获取本机公网 IP (通过 ip.sb)..."
IPV4=$(curl -s4 https://api-ipv4.ip.sb/ip | tr -d '\n')
IPV6=$(curl -s6 https://api-ipv6.ip.sb/ip | tr -d '\n')

echo ""
echo "########################################################"
echo "           Sing-Box SOCKS5 部署成功"
echo "########################################################"
echo " 服务名称 : $SERVICE_NAME"
echo " 配置文件 : $CONF_FILE"
echo "--------------------------------------------------------"
echo " 用户名   : $SOCKS_USER"
echo " 密码     : $SOCKS_PASS"
echo " 端口     : $SOCKS_PORT"
echo "--------------------------------------------------------"
echo " [链接格式]"

if [ -n "$IPV4" ]; then
    echo ""
    echo " IPv4 地址: $IPV4"
    echo " SOCKS5链接: socks5://$SOCKS_USER:$SOCKS_PASS@$IPV4:$SOCKS_PORT"
else
    echo " IPv4 地址: 未检测到"
fi

if [ -n "$IPV6" ]; then
    echo ""
    echo " IPv6 地址: $IPV6"
    # IPv6 在 URL 中需要加方括号 []
    echo " SOCKS5链接: socks5://$SOCKS_USER:$SOCKS_PASS@[$IPV6]:$SOCKS_PORT"
else
    echo " IPv6 地址: 未检测到"
fi

echo "########################################################"
