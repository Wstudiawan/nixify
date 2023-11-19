#!/bin/bash
#set -e

TIME_NOW="$(date "+%b %d %Y %Hh:%Mm:%Ss %Z")"
OS_INFO="$(grep PRETTY_NAME /etc/os-release | sed 's/PRETTY_NAME=//g' | tr -d '="' | sed 's/\./\\./g' | sed 's/\-/\\-/g')"
echo $OS_INFO # test
HOST_KERNEL="$(uname -r| sed 's/\./\\./g' | sed 's/\-/\\-/g')"
HOST_CORES="$(nproc --all)"

if [ -z "$1" ]; then
    echo "No version specified."
    VERSION="alpha"
else
    VERSION="v$1"
fi

ZIP_NAME="Daemon-$VERSION.zip"

log() {
    local message=$1
    local color=$2
    local style=$3
    local color_code="\e[${color}m"
    local style_code="\e[${style}m"
    local reset_code="\e[0m"
    echo -e "${style_code}${color_code}${message}${reset_code}"
}


if [ -f "/etc/apt/sources.list" ]; then
    sudo apt-get install binutils-aarch64-linux-gnu
else
    # sudo pacman -S binutils-aarch64-linux-gnu
    log "Archlinux detected" 32 1
fi

device="munch"
# test_channel="-1001410447029"   # group
test_channel="-1001421078455" # channel
# test_channel="-1001356262990"      # test channel

function tg() {
    local action="$1"
    local text="$2"
    local CHAT_ID="$3"
    local initial_message="$4"
    local doc_path="$5"
    local doc_caption="$6"

    if [ "$action" == "s" ]; then
        local message_response=$(curl --request POST \
            --url "https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/sendMessage" \
            --data "disable_web_page_preview=true" \
            --data "disable_notification=true" \
            --data "parse_mode=MarkdownV2" \
            --data "chat_id=-1001421078455" \
            --data text="$text")

        if
            [ "$initial_message" == "true" ]
        then
            first_message_id=$(echo $message_response | jq .result.message_id) && last_message_id=$first_message_id
        else
            last_message_id=$(echo $message_response | jq .result.message_id)
        fi

    elif [ "$action" == "e" ]; then
        if [ -z "$last_message_id" ]; then
            echo "No message to edit. Send a message first."
            exit 1
        fi

        if
            [ "$initial_message" == "true" ]
        then
            last_message_id=$first_message_id
        fi
        
        if [ -n "$text" ]; then
            local message_response=$(curl -s --request POST \
            --url "https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/editMessageText" \
            --data text="$text" \
            --data "disable_web_page_preview=true" \
            --data "disable_notification=true" \
            --data "parse_mode=MarkdownV2" \
            --data "chat_id=-1001421078455" \
            --data "message_id=${last_message_id}")

            last_message_id=$(echo $message_response | jq .result.message_id)
        fi
    elif [ "$action" == "d" ]; then
        if [ -z "$last_message_id" ]; then
            echo "No message to delete. Send a message first."
            exit 1
        fi

        curl --request POST \
            --url "https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/deleteMessage" \
            --data "chat_id=-1001421078455" \
            --data "message_id=${last_message_id}"

        last_message_id=""
    elif [ "$action" == "doc" ]; then
        if [ -n "$doc_path" ]; then
            curl -F document=@"$doc_path" \
                "https://api.telegram.org/bot1446507242:AAFivf422Yvh3CL7y98TJmxV1KgyKByuPzM/sendDocument" \
                -F chat_id="-1001421078455" -F caption="$doc_caption" -F "parse_mode=MarkdownV2"  -o /dev/null
        fi
    else
        echo "Invalid action: $action"
        exit 1
    fi
}

log "******************************************" 33 1
log "*   Cloning AOSP Clang                   *" 32 1
log "******************************************" 33 1
DIR=`readlink -f .`
MAIN=`readlink -f ${DIR}/..`
if [ -d "$MAIN/clang" ]; then
    log "Toolchain already exist!" 32 1
    log ""
else
    log "Downloading AOSP Clang 17.0.3" 32 1
    curl https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r498229.tar.gz -o "aosp-clang.tar.gz"
    mkdir "$MAIN"/clang && tar -xf aosp-clang.tar.gz -C "$MAIN"/clang && rm -rf aosp-clang.tar.gz
fi

export ARCH=arm64
export SUBARCH=arm64


KERNEL_DIR=$(pwd)
ZIMAGE_DIR="$KERNEL_DIR/out/arch/arm64/boot"


CLANG_DIR="$MAIN/clang"
KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
PATH="$CLANG_DIR/bin:$PATH"

BUILD_START=$(date +"%s")
log "******************************************" 33 1
log "*   Checking and updating kernelSU       *" 32 1
log "******************************************" 33 1

curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -

log "******************************************" 33 1
log "*          Making munch_defconfig        *" 32 1
log "******************************************" 33 1

make munch_defconfig O=out LLVM=1 \
                ARCH=arm64 \
                CC=clang \
                CROSS_COMPILE=aarch64-linux-gnu- \
                NM=llvm-nm \
                OBJDUMP=llvm-objdump \
                STRIP=llvm-strip

log "******************************************" 33 1
log "*          Compiling Kernel              *" 32 1
log "******************************************" 33 1
make -j16 O=out \
    LLVM=1 \
    ARCH=arm64 \
    CC=clang \
    CROSS_COMPILE=aarch64-linux-gnu- \
    NM=llvm-nm \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))
TOTAL_TIME="Build completed in $(($DIFF / 60)) minute\(s\) and $(($DIFF % 60)) seconds\."

mkdir -p tmp
cp -fp "$ZIMAGE_DIR/Image.gz" tmp
# cp -fp $ZIMAGE_DIR/dtbo.img tmp
mv "$ZIMAGE_DIR/dtb.img" "$ZIMAGE_DIR/dtb"
cp -fp "$ZIMAGE_DIR/dtb" tmp
cp -rp ./anykernel3/* tmp
cd tmp
zip -r -9 "tmp.zip" *
cd ..
rm *.zip
cp -fp "tmp/tmp.zip" "$ZIP_NAME"
rm -rf tmp

CAPTION='
*Device:* _Poco F4 \(munch\)_

*Build triggered at:*
*'$TIME_NOW'*

*'$TOTAL_TIME'*

*Compiler*: _AOSP Clang 17\.0\.3_
*LD* :_GNU ld \(GNU Binutils\) 2\.41\.0_
*Host Kernel* : _'$HOST_KERNEL'_
*Host Cores* : _'$HOST_CORES'_

'
tg "doc" "" "$test_channel" "true" "$ZIP_NAME" "$CAPTION"

log "Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds." 32 1

# git reset --hard
