cat /etc/issue

echo "PWD: $PWD"

mount
df -h

ls -l ${HOME}/srv/toolchain/

gcc --version
g++ --version
ccache --version
python3 --version
