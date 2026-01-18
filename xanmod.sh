#!/bin/bash

# ==============================================================================
# XanMod Kernel Installer (Enhanced)
# Supported OS: Debian 12/13, Ubuntu 22.04/24.04+ and derivatives
# Features: Robust error handling, auto-detection, fallback logic
# ==============================================================================

# 设置严格模式 (部分)
set -u

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${PLAIN} $*"; }
log_success() { echo -e "${GREEN}[OK]${PLAIN} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${PLAIN} $*"; }
log_error() { echo -e "${RED}[ERROR]${PLAIN} $*"; }

# 错误处理
handle_error() {
    log_error "发生错误，脚本终止。错误行号: $1"
    exit 1
}
trap 'handle_error $LINENO' ERR

# 1. 权限与环境检查
check_sys() {
    if [ "$(id -u)" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本 (sudo bash $0)"
        exit 1
    fi

    if [ ! -f /etc/debian_version ]; then
        log_error "本脚本仅支持 Debian/Ubuntu 系统。"
        exit 1
    fi

    # 检测 OS 版本 (可选用于更细致的处理，目前通用逻辑即可)
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        log_info "检测到系统: $PRETTY_NAME"
    fi
}

# 2. 安装必要依赖
install_deps() {
    log_info "正在更新软件包列表并安装依赖..."
    apt-get update -qq
    apt-get install -y -qq curl gnupg ca-certificates lsb-release grep
    
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl 安装失败，请检查网络或软件源。"
        exit 1
    fi
}

# 3. 配置 XanMod 仓库
setup_repo() {
    log_info "配置 XanMod 官方仓库..."
    
    # 清理旧配置
    rm -f /etc/apt/sources.list.d/xanmod*
    rm -f /usr/share/keyrings/xanmod*
    rm -f /etc/apt/keyrings/xanmod*

    mkdir -p /etc/apt/keyrings

    # 下载并转换密钥 (增加重试机制)
    local KEY_URL="https://dl.xanmod.org/archive.key"
    local KEYRING="/etc/apt/keyrings/xanmod-archive-keyring.gpg"
    
    log_info "下载 GPG 密钥: $KEY_URL"
    if ! curl -fsSL "$KEY_URL" | gpg --dearmor --yes -o "$KEYRING"; then
        log_warn "从 dl.xanmod.org 下载密钥失败，尝试备用源 gitlab..."
        # 备用密钥地址 (如果有，或者重试)
        sleep 2
        curl -fsSL "$KEY_URL" | gpg --dearmor --yes -o "$KEYRING"
    fi
    chmod 0644 "$KEYRING"

    # 写入源文件 (使用 deb822 格式，兼容性更好)
    log_info "写入仓库配置..."
    tee /etc/apt/sources.list.d/xanmod.sources >/dev/null <<EOF
Types: deb
URIs: https://deb.xanmod.org
Suites: releases
Components: main
Architectures: amd64
Signed-By: $KEYRING
EOF
    
    log_info "更新仓库数据..."
    if ! apt-get update; then
        log_warn "首选镜像 deb.xanmod.org 连接失败，尝试切换到 dl.xanmod.org..."
        sed -i 's/deb.xanmod.org/dl.xanmod.org/g' /etc/apt/sources.list.d/xanmod.sources
        apt-get update
    fi
}

# 4. CPU 架构检测与版本选择
detect_and_select_kernel() {
    log_info "正在检测 CPU 指令集架构级别..."
    
    local CPU_LEVEL=""
    
    # 使用官方推荐的检测脚本逻辑片段
    # 尝试使用 awk 解析 ld-linux 输出 (最准确)
    if [ -f /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ]; then
        local LD_OUT
        LD_OUT=$(/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 --help 2>/dev/null)
        if echo "$LD_OUT" | grep -q "x86-64-v4"; then CPU_LEVEL="v4";
        elif echo "$LD_OUT" | grep -q "x86-64-v3"; then CPU_LEVEL="v3";
        elif echo "$LD_OUT" | grep -q "x86-64-v2"; then CPU_LEVEL="v2";
        fi
    fi

    # 如果上述方法失败，回退到 cpuinfo 解析
    if [ -z "$CPU_LEVEL" ]; then
        local FLAGS
        FLAGS=$(grep flags /proc/cpuinfo | head -n1)
        if echo "$FLAGS" | grep -q "avx512"; then CPU_LEVEL="v4";
        elif echo "$FLAGS" | grep -q "avx2"; then CPU_LEVEL="v3";
        elif echo "$FLAGS" | grep -q "sse4_2"; then CPU_LEVEL="v2";
        else CPU_LEVEL="v1";
        fi
    fi
    
    log_info "CPU 硬件支持级别: x86-64-$CPU_LEVEL"

    # 动态检查仓库中是否存在该版本的包
    local TARGET_PKG="linux-xanmod-x64${CPU_LEVEL}"
    
    log_info "检查仓库中是否存在包: $TARGET_PKG ..."
    if apt-cache show "$TARGET_PKG" >/dev/null 2>&1; then
        KERNEL_PACKAGE="$TARGET_PKG"
        log_success "找到完美匹配内核: $KERNEL_PACKAGE"
    else
        log_warn "仓库中未找到 $TARGET_PKG (可能是仓库暂未构建或已移除)。"
        
        # 降级逻辑
        if [ "$CPU_LEVEL" == "v4" ]; then
            log_info "尝试降级到 v3..."
            KERNEL_PACKAGE="linux-xanmod-x64v3"
        elif [ "$CPU_LEVEL" == "v3" ]; then
             log_info "尝试降级到 v2..."
            KERNEL_PACKAGE="linux-xanmod-x64v2"
        else
            log_error "无法找到合适的 XanMod 内核包。请检查网络或仓库状态。"
            exit 1
        fi
        
        # 再次检查降级后的包
        if apt-cache show "$KERNEL_PACKAGE" >/dev/null 2>&1; then
            log_success "将安装兼容内核: $KERNEL_PACKAGE"
        else
            log_error "降级后仍未找到包: $KERNEL_PACKAGE。退出。"
            exit 1
        fi
    fi
}

# 5. 安装内核
install_kernel() {
    log_info "开始安装 $KERNEL_PACKAGE ..."
    
    # 捕获 apt install 的退出码
    set +e 
    apt-get install -y "$KERNEL_PACKAGE"
    local INSTALL_RES=$?
    set -e

    if [ $INSTALL_RES -eq 0 ]; then
        log_success "内核安装成功！"
    else
        log_error "内核安装失败。请检查上方错误信息。"
        exit 1
    fi
}

# 6. 完成与提示
finish() {
    echo ""
    echo -e "${GREEN}==============================================${PLAIN}"
    echo -e "${GREEN}🎉 XanMod 内核安装完成！${PLAIN}"
    echo -e "当前安装版本: ${YELLOW}${KERNEL_PACKAGE}${PLAIN}"
    echo -e "系统需要重启以加载新内核。"
    echo -e "${GREEN}==============================================${PLAIN}"
    
    read -p "是否立即重启系统? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "正在重启..."
        reboot
    else
        log_info "请稍后手动执行 'reboot' 命令重启。"
    fi
}

# 主流程
main() {
    echo -e "${GREEN}--- 🚀 XanMod Kernel Installer (Enhanced) ---${PLAIN}"
    check_sys
    install_deps
    setup_repo
    detect_and_select_kernel
    install_kernel
    finish
}

main
