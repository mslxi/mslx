#!/bin/bash

# 颜色定义
red() { echo -e "\033[31m$1\033[0m"; }
green() { echo -e "\033[32m$1\033[0m"; }
yellow() { echo -e "\033[33m$1\033[0m"; }

# 全局变量
IS_CHINA=false

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        yellow "警告: 非root用户，某些操作可能需要sudo权限"
        SUDO_CMD="sudo"
    else
        SUDO_CMD=""
    fi
}

# 检查地区
check_region() {
    yellow "正在检测网络环境..."
    
    # 尝试多种方式检测是否在中国大陆
    
    # 方法1: 通过 Cloudflare Trace (通常较快且准确)
    if curl -s --connect-timeout 3 https://www.cloudflare.com/cdn-cgi/trace | grep -q "loc=CN"; then
        IS_CHINA=true
    # 方法2: 通过连通性测试 (Google vs Baidu)
    elif ! curl -s --connect-timeout 3 https://www.google.com >/dev/null 2>&1; then
        if curl -s --connect-timeout 3 https://www.baidu.com >/dev/null 2>&1; then
            IS_CHINA=true
        fi
    fi

    if [[ "$IS_CHINA" == "true" ]]; then
        green "检测到中国大陆环境，将使用国内镜像源加速下载"
    else
        green "检测到海外环境，将使用官方源"
    fi
}

# 安装依赖包
install_dependencies() {
    local depends=("curl" "wget" "git" "zsh")
    local missing_deps=""
    
    # 检查缺失的依赖
    for dep in "${depends[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps="$dep $missing_deps"
        fi
    done
    
    if [[ -n "$missing_deps" ]]; then
        yellow "正在安装缺失的依赖: $missing_deps"
        
        # 根据不同的包管理器安装
        if command -v apk >/dev/null 2>&1; then
            $SUDO_CMD apk update && $SUDO_CMD apk add $missing_deps
        elif command -v apt-get >/dev/null 2>&1; then
            $SUDO_CMD apt update -y && $SUDO_CMD apt install -y $missing_deps
        elif command -v yum >/dev/null 2>&1; then
            $SUDO_CMD yum update -y && $SUDO_CMD yum install -y $missing_deps
        elif command -v dnf >/dev/null 2>&1; then
            $SUDO_CMD dnf update -y && $SUDO_CMD dnf install -y $missing_deps
        elif command -v pacman >/dev/null 2>&1; then
            $SUDO_CMD pacman -Sy --noconfirm $missing_deps
        elif command -v zypper >/dev/null 2>&1; then
            $SUDO_CMD zypper refresh && $SUDO_CMD zypper install -y $missing_deps
        else
            red "错误: 未找到合适的包管理工具，请手动安装: $missing_deps"
            exit 1
        fi
        
        # 验证安装结果
        for dep in "${depends[@]}"; do
            if ! command -v "$dep" >/dev/null 2>&1; then
                red "错误: $dep 安装失败"
                exit 1
            fi
        done
        green "依赖安装完成"
    else
        green "所有依赖已存在"
    fi
}

# 安装 Oh My Zsh
install_oh_my_zsh() {
    local zsh_dir="${HOME}/.oh-my-zsh"
    
    if [[ -d "$zsh_dir" ]]; then
        yellow "Oh My Zsh 已安装，跳过安装步骤"
        return 0
    fi
    
    yellow "正在安装 Oh My Zsh..."
    
    if [[ "$IS_CHINA" == "true" ]]; then
        # 大陆环境配置
        # 设置 REMOTE 环境变量，Oh My Zsh 官方安装脚本支持此变量来自定义仓库地址
        export REMOTE="https://gitee.com/mirrors/oh-my-zsh.git"
        
        # 尝试使用 Gitee 上的安装脚本镜像 (通常与官方保持同步)
        # 或者使用 jsdelivr 加速的 GitHub 文件
        local install_urls=(
            "https://gitee.com/mirrors/oh-my-zsh/raw/master/tools/install.sh"
            "https://cdn.jsdelivr.net/gh/ohmyzsh/ohmyzsh@master/tools/install.sh"
        )
        
        for url in "${install_urls[@]}"; do
            yellow "尝试从镜像源下载安装脚本: $url"
            # 注意: 这里需要确保 REMOTE 变量在 sh 进程中生效
            if curl -fsSL "$url" | sh -s -- --unattended >/dev/null 2>&1; then
                green "Oh My Zsh 安装成功 (使用国内镜像)"
                return 0
            fi
        done
    else
        # 海外环境配置
        local url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
        yellow "尝试从官方源下载..."
        if curl -fsSL "$url" | sh -s -- --unattended >/dev/null 2>&1; then
            green "Oh My Zsh 安装成功"
            return 0
        fi
    fi
    
    red "错误: Oh My Zsh 安装失败，请检查网络连接"
    return 1
}

# 设置默认Shell为zsh
set_default_shell() {
    local current_shell=$(echo $SHELL)
    local zsh_path=$(which zsh)
    
    if [[ "$current_shell" == "$zsh_path" ]]; then
        green "当前Shell已经是zsh"
        return 0
    fi
    
    yellow "正在设置zsh为默认Shell..."
    
    # 检查zsh是否在/etc/shells中
    if ! grep -q "$zsh_path" /etc/shells 2>/dev/null; then
        yellow "将zsh路径添加到/etc/shells..."
        echo "$zsh_path" | $SUDO_CMD tee -a /etc/shells >/dev/null
    fi
    
    # 尝试修改默认Shell
    if command -v chsh >/dev/null 2>&1; then
        if chsh -s "$zsh_path" 2>/dev/null; then
            green "默认Shell设置成功，请重新登录或执行 'exec zsh' 生效"
        else
            # 如果chsh失败，尝试使用sudo (针对当前用户)
            if $SUDO_CMD chsh -s "$zsh_path" "$USER" 2>/dev/null; then
                green "默认Shell设置成功，请重新登录或执行 'exec zsh' 生效"
            else
                yellow "警告: 无法自动设置默认Shell，请手动执行: chsh -s $zsh_path"
                yellow "或者在 ~/.bashrc 或 ~/.bash_profile 中添加: exec zsh"
            fi
        fi
    else
        yellow "警告: chsh命令不可用，请手动设置默认Shell"
    fi
}

# 配置zsh主题和插件
configure_zsh() {
    local zshrc_file="${HOME}/.zshrc"
    
    if [[ ! -f "$zshrc_file" ]]; then
        red "错误: .zshrc 文件不存在"
        return 1
    fi
    
    # 设置主题
    yellow "配置zsh主题..."
    if grep -q "^ZSH_THEME=" "$zshrc_file"; then
        sed -i 's/^ZSH_THEME=".*"/ZSH_THEME="wedisagree"/' "$zshrc_file"
    else
        echo 'ZSH_THEME="wedisagree"' >> "$zshrc_file"
    fi
    
    # 安装插件
    local custom_dir="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"
    local plugins_dir="${custom_dir}/plugins"
    
    # 创建插件目录
    mkdir -p "$plugins_dir"
    
    # 插件列表和对应的仓库地址
    declare -A plugins
    
    if [[ "$IS_CHINA" == "true" ]]; then
        # 国内使用 Gitee 镜像
        plugins=(
            ["zsh-syntax-highlighting"]="https://gitee.com/mirrors/zsh-syntax-highlighting.git"
            ["zsh-autosuggestions"]="https://gitee.com/mirrors/zsh-autosuggestions.git"
        )
    else
        # 官方源
        plugins=(
            ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
            ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions.git"
        )
    fi
    
    # 安装插件
    for plugin in "${!plugins[@]}"; do
        local plugin_dir="${plugins_dir}/${plugin}"
        local repo_url="${plugins[$plugin]}"
        
        if [[ ! -d "$plugin_dir" ]]; then
            yellow "正在安装插件: $plugin (源: $repo_url)"
            if git clone "$repo_url" "$plugin_dir" 2>/dev/null; then
                green "插件 $plugin 安装成功"
            else
                red "插件 $plugin 安装失败"
            fi
        else
            green "插件 $plugin 已存在"
        fi
    done
    
    # 更新插件配置
    yellow "更新插件配置..."
    if grep -q "^plugins=" "$zshrc_file"; then
        # 获取当前插件配置
        local current_plugins=$(grep "^plugins=" "$zshrc_file" | sed 's/plugins=(//' | sed 's/)//')
        
        # 检查并添加新插件
        local new_plugins="git z extract zsh-syntax-highlighting zsh-autosuggestions"
        for plugin in $new_plugins; do
            if ! echo "$current_plugins" | grep -q "$plugin"; then
                current_plugins="$current_plugins $plugin"
            fi
        done
        
        # 更新插件配置
        sed -i "s/^plugins=.*/plugins=($current_plugins)/" "$zshrc_file"
    else
        echo "plugins=(git z extract zsh-syntax-highlighting zsh-autosuggestions)" >> "$zshrc_file"
    fi
    
    green "zsh配置完成"
}

# 主函数
main() {
    green "开始配置zsh环境..."
    
    check_root
    
    # 检测地区
    check_region
    
    # 安装依赖
    install_dependencies
    
    # 验证zsh安装
    if ! command -v zsh >/dev/null 2>&1; then
        red "错误: zsh安装失败"
        exit 1
    fi
    
    # 安装Oh My Zsh
    if ! install_oh_my_zsh; then
        exit 1
    fi
    
    # 配置zsh
    configure_zsh
    
    # 设置默认Shell
    set_default_shell
    
    green "==================================="
    green "zsh环境配置完成!"
    green "==================================="
    yellow "建议执行以下命令之一来开始使用zsh:"
    yellow "1. exec zsh          # 在当前会话切换到zsh"
    yellow "2. 重新登录系统        # 如果默认Shell设置成功"
    yellow "3. 在新终端窗口中使用   # 新窗口将使用zsh"
}

# 执行主函数
main "$@"