#!/bin/bash

# 准备环境
prepare_environment() {
    echo "正在准备环境..."
    # 更换源为清华源
    sed -i 's@^\(deb.*stable main\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/termux-packages-24 stable main@' $PREFIX/etc/apt/sources.list
    sed -i 's@^\(deb.*games stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/game-packages-24 games stable@' $PREFIX/etc/apt/sources.list.d/game.list
    sed -i 's@^\(deb.*science stable\)$@#\1\ndeb https://mirrors.tuna.tsinghua.edu.cn/termux/science-packages-24 science stable@' $PREFIX/etc/apt/sources.list.d/science.list
    pkg update -y
    pkg install -y proot-distro screen curl wget
    if [ $? -ne 0 ]; then
        echo "环境准备失败。"
        exit 1
    fi
}

# 检查MongoDB是否已安装
check_mongodb() {
    if command -v mongod &> /dev/null; then
        echo "MongoDB已安装，跳过安装。"
        return 0
    fi
    return 1
}

# 安装MongoDB
install_mongodb() {
    if check_mongodb; then
        return 0
    fi

    echo "正在安装MongoDB..."
    
    echo "添加第三方存储库..."
    curl -O https://its-pointless.github.io/setup-pointless-repo.sh
    bash setup-pointless-repo.sh
    if [ $? -ne 0 ]; then
        echo "添加第三方存储库失败。"
        exit 1
    fi
    
    echo "安装MongoDB..."
    pkg install -y mongodb
    if [ $? -ne 0 ]; then
        echo "MongoDB安装失败。"
        exit 1
    fi
    
    echo "MongoDB安装成功"
}

# 检查napcat是否已安装
check_napcat() {
    if proot-distro list | grep -q "napcat"; then
        echo "napcat容器已安装，跳过安装。"
        return 0
    fi
    return 1
}

# 安装napcat容器
install_napcat() {
    if check_napcat; then
        return 0
    fi

    echo "正在安装napcat容器..."
    proot-distro install debian --override-alias napcat
    if [ $? -ne 0 ]; then
        echo "napcat容器安装失败。"
        exit 1
    fi

    echo "正在初始化napcat容器..."
    init_cmd="apt update -y && \
    apt install -y sudo curl && \
    curl -o napcat.sh https://nclatest.znin.net/NapNeko/NapCat-Installer/main/script/install.sh && \
    sudo bash napcat.sh --docker n && \
    apt autoremove -y && \
    apt clean && \
    rm -rf /tmp/* /var/lib/apt/lists"
    proot-distro sh napcat -- bash -c "$init_cmd"
    if [ $? -ne 0 ]; then
        proot-distro remove napcat
        echo "napcat容器初始化失败。"
        exit 1
    fi
    echo "napcat容器安装成功"
}

# 检查Python版本
check_python_version() {
    if command -v python3 &>/dev/null; then
        python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        if [ "$(printf '%s\n' "3.11" "$python_version" | sort -V | head -n1)" = "3.11" ]; then
            echo "检测到Python版本 $python_version，满足要求，跳过安装。"
            return 0
        fi
    fi
    return 1
}

# 安装Python 3.12
install_python() {
    if check_python_version; then
        return 0
    fi
    echo "正在安装Python 3.12..."
    pkg install -y python
    if [ $? -ne 0 ]; then
        echo "Python 3.12 安装失败。"
        exit 1
    fi
    echo "Python 3.12 安装成功"
}

# 安装和配置QQ机器人项目
setup_qq_bot() {
    echo "正在设置QQ机器人项目..."
    proot-distro login napcat -- bash -c "
        cd /root &&
        git clone https://github.com/syuchua/QFurina.git &&
        cd QFurina &&
        python -m pip install -r requirements.txt
    "
    if [ $? -ne 0 ]; then
        echo "QQ机器人项目设置失败。"
        exit 1
    fi
    echo "QQ机器人项目已设置完成"
    echo "请进入napcat容器，进入/root/MY_QBOT目录，编辑配置文件填写api_key等变量。"
    echo "编辑完成后，可以使用 'python main.py' 启动项目（假设入口文件是main.py）。"
}

# 主程序
main() {
    prepare_environment
    install_mongodb
    install_napcat
    install_python
    setup_qq_bot
    
    echo "安装和配置完成。"
    echo "您可以使用以下命令管理各个组件："
    echo "- 进入napcat容器：proot-distro login napcat"
    echo "- 启动MongoDB：mongod --dbpath=data/db --bind_ip=0.0.0.0 --fork --logpath=/data/data/com.termux/files/usr/tmp/mongod.log"
    echo "- 启动napcat：screen -dmS napcat bash -c 'proot-distro login napcat -- bash -c \"cd /opt/QQ && xvfb-run -a qq --no-sandbox\"'"
    echo "- 查看napcat日志：screen -r napcat"
    echo "- 进入QQ机器人项目目录：cd /root/MY_QBOT"
    echo "- 启动QQ机器人项目：python main.py"
    echo "注意：请确保在启动QQ机器人项目之前，已经正确配置了api_key等必要变量。"
    echo "建议您观看视频教程了解如何运行各个组件。"
}

# 执行主程序
main