#!/usr/bin/env bash
set -e

### CONFIG ###
ISO_URL="https://go.microsoft.com/fwlink/p/?LinkID=2195443"
ISO_FILE="win11-gamer.iso"

DISK_FILE="/var/win11.qcow2"
DISK_SIZE="64G"

RAM="16G"
CORES="4"

VNC_DISPLAY=":0"
RDP_PORT="3389"
VNC_PORT="5900"

FLAG_FILE="installed.flag"
WORKDIR="$HOME/windows-idx"

### LOCALTONET CONFIG ###
# 👉 ĐĂNG KÝ TẠI: https://localtonet.com
# 👉 LẤY TOKEN TỪ: Dashboard → Auth → Tokens
LOCALTONET_TOKEN=""  # <--- QUAN TRỌNG: NHẬP TOKEN VÀO ĐÂY
LOCALTONET_DIR="$HOME/.localtonet"
LOCALTONET_BIN="$LOCALTONET_DIR/localtonet"
LOCALTONET_LOG="$LOCALTONET_DIR/tunnel.log"

### CHECK ###
[ -e /dev/kvm ] || { echo "❌ No /dev/kvm"; exit 1; }
command -v qemu-system-x86_64 >/dev/null || { echo "❌ No qemu"; exit 1; }
command -v wget >/dev/null || { echo "❌ Please install wget"; exit 1; }
command -v unzip >/dev/null || { echo "❌ Please install unzip"; exit 1; }

### PREP ###
mkdir -p "$WORKDIR"
cd "$WORKDIR"

[ -f "$DISK_FILE" ] || qemu-img create -f qcow2 "$DISK_FILE" "$DISK_SIZE"

if [ ! -f "$FLAG_FILE" ]; then
  [ -f "$ISO_FILE" ] || wget --no-check-certificate \
    -O "$ISO_FILE" "$ISO_URL"
fi


############################
# BACKGROUND FILE CREATOR #
############################
(
  while true; do
    echo "Lộc Nguyễn đẹp troai" > locnguyen.txt
    echo "[$(date '+%H:%M:%S')] Đã tạo locnguyen.txt"
    sleep 300
  done
) &
FILE_PID=$!


#########################
# LOCALTONET SETUP     #
#########################
mkdir -p "$LOCALTONET_DIR"

# Tải localtonet client nếu chưa có
if [ ! -f "$LOCALTONET_BIN" ]; then
  echo "📥 Đang tải localtonet client..."
  cd "$LOCALTONET_DIR"
  wget -q --show-progress https://localtonet.com/download/localtonet-linux-64bit.zip
  unzip -q localtonet-linux-64bit.zip
  rm localtonet-linux-64bit.zip
  chmod +x localtonet
  cd "$WORKDIR"
fi

# Xác thực với token
echo "🔑 Đang xác thực localtonet..."
"$LOCALTONET_BIN" auth "$LOCALTONET_TOKEN"

# Kill tunnel cũ nếu đang chạy
pkill -f "$LOCALTONET_BIN" 2>/dev/null || true

# Tạo file cấu hình cho 2 tunnels
cat > "$LOCALTONET_DIR/config.yaml" <<EOF
tunnels:
  rdp-tunnel:
    proto: tcp
    addr: $RDP_PORT
    bind_port: 0  # random port, lấy từ log
  vnc-tunnel:
    proto: tcp
    addr: $VNC_PORT
    bind_port: 0  # random port, lấy từ log
EOF

# Chạy localtonet và ghi log
echo "🚀 Đang khởi động tunnels..."
nohup "$LOCALTONET_BIN" start --config "$LOCALTONET_DIR/config.yaml" > "$LOCALTONET_LOG" 2>&1 &

# Đợi tunnel khởi tạo
sleep 8

# Hàm lấy địa chỉ public từ log
get_tunnel_url() {
  local port=$1
  local pattern="tunnel started:.*:${port}"
  grep -E "$pattern" "$LOCALTONET_LOG" | tail -1 | grep -oE 'tcp://[^ ]+' || echo "⏳ Đang chờ..."
}

RDP_ADDR=$(get_tunnel_url $RDP_PORT)
VNC_ADDR=$(get_tunnel_url $VNC_PORT)

echo ""
echo "========================================="
echo "🌍 RDP PUBLIC: $RDP_ADDR"
echo "🌍 VNC PUBLIC: $VNC_ADDR"
echo "========================================="
echo ""
echo "📝 Log chi tiết: tail -f $LOCALTONET_LOG"
echo ""


#########################
# RUN QEMU             #
#########################
if [ ! -f "$FLAG_FILE" ]; then
  echo "⚠️  CHẾ ĐỘ CÀI ĐẶT WINDOWS"
  echo "👉 DÙNG VNC CLIENT KẾT NỐI VÀO ĐỊA CHỈ TRÊN ĐỂ CÀI WINDOWS"
  echo "👉 CÀI XONG QUAY LẠI ĐÂY NHẬP: xong"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot order=d \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389,hostfwd=tcp::5900-:5900 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet &

  QEMU_PID=$!

  while true; do
    read -rp "👉 Nhập 'xong' khi đã cài Windows xong: " DONE
    if [ "$DONE" = "xong" ]; then
      touch "$FLAG_FILE"
      kill "$QEMU_PID" 2>/dev/null
      kill "$FILE_PID" 2>/dev/null
      pkill -f "$LOCALTONET_BIN" 2>/dev/null
      rm -f "$ISO_FILE"
      echo "✅ Hoàn tất cài đặt – lần sau boot thẳng qcow2"
      exit 0
    fi
  done

else
  echo "✅ Windows đã cài – boot thường"
  echo "👉 KẾT NỐI RDP: $RDP_ADDR"
  echo "👉 KẾT NỐI VNC: $VNC_ADDR"

  qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp "$CORES" \
    -m "$RAM" \
    -machine q35 \
    -drive file="$DISK_FILE",if=ide,format=qcow2 \
    -boot order=c \
    -netdev user,id=net0,hostfwd=tcp::3389-:3389,hostfwd=tcp::5900-:5900 \
    -device e1000,netdev=net0 \
    -vnc "$VNC_DISPLAY" \
    -usb -device usb-tablet
fi
