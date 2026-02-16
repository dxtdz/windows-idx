{ pkgs, ... }:

{
  # Danh sách package cần cài đặt
  packages = with pkgs; [
    # QEMU đầy đủ
    qemu_full
    wget
    unzip         # <--- THÊM: để giải nén localtonet
    gnused        # <--- THÊM: cho lệnh sed (xử lý text)
    gnugrep       # <--- THÊM: cho lệnh grep
    coreutils     # <--- THÊM: các lệnh cơ bản
  ];

  # Script chạy khi workspace khởi động
  idx.workspace.onStart = {
    # Tạo thư mục và chạy script chính
    setup-windows = ''
      # Tạo thư mục làm việc
      mkdir -p /home/user/windows-idx
      cd /home/user/windows-idx

      # Copy script run.sh vào đúng vị trí
      cp /home/user/windows-idx/run.sh ./ 2>/dev/null || \
        wget -O run.sh https://raw.githubusercontent.com/pdb7tsghyb-beep/windows-idx/main/run.sh

      # Thay token ngrok bằng token localtonet (nếu chưa thay)
      # ⚠️ QUAN TRỌNG: Thay YOUR_TOKEN bằng token thật từ localtonet.com
      sed -i 's/LOCALTONET_TOKEN=".*"/LOCALTONET_TOKEN="Ek57xXNWi2rStCPu86JcFpoj1v9dRsOD3"/g' run.sh

      # Phân quyền và chạy
      chmod +x run.sh
      
      echo "========================================="
      echo "🚀 ĐANG KHỞI ĐỘNG WINDOWS + LOCALTONET..."
      echo "========================================="
      
      # Chạy script trong background để không block IDX
      bash run.sh > /tmp/windows.log 2>&1 &
      
      # Đợi 10 giây để tunnel khởi tạo
      sleep 10
      
      # Hiển thị địa chỉ kết nối
      echo ""
      echo "📊 TRẠNG THÁI TUNNEL:"
      echo "--------------------"
      if [ -f /home/user/.localtonet/tunnel.log ]; then
        grep "tunnel started" /home/user/.localtonet/tunnel.log | tail -2
      else
        echo "⏳ Đang khởi tạo tunnel... xem log: tail -f /home/user/.localtonet/tunnel.log"
      fi
      
      echo ""
      echo "📝 Xem log chi tiết: tail -f /tmp/windows.log"
    '';
  };

  # Script chạy khi mở terminal (tiện lợi để kiểm tra)
  idx.workspace.onOpen = {
    show-status = ''
      echo "========================================="
      echo "🪟 WINDOWS-IDX VỚI LOCALTONET"
      echo "========================================="
      echo "📋 LỆNH HỮU ÍCH:"
      echo "  • Xem log Windows:     tail -f /tmp/windows.log"
      echo "  • Xem tunnel status:   tail -f /home/user/.localtonet/tunnel.log"
      echo "  • Kiểm tra process:    ps aux | grep -E 'qemu|localtonet'"
      echo "  • Dừng Windows:        pkill qemu"
      echo "========================================="
      
      # Hiển thị địa chỉ tunnel nếu có
      if [ -f /home/user/.localtonet/tunnel.log ]; then
        echo "🌍 ĐỊA CHỈ PUBLIC HIỆN TẠI:"
        grep "tunnel started" /home/user/.localtonet/tunnel.log | tail -2 | sed 's/.*tunnel started: //'
      fi
    '';
  };

  # Biến môi trường
  env = {
    QEMU_AUDIO_DRV = "none";
    LOCALTONET_HOME = "/home/user/.localtonet";
  };
}
