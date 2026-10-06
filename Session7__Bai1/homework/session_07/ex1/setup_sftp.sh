#!/usr/bin/env bash
# ==============================================================================
# Script: setup_sftp.sh
# Mục đích: Tự động hóa khởi tạo tài khoản sftp-user, tạo dữ liệu log mẫu
#           và phân quyền truy cập an toàn theo nguyên tắc Least Privilege
# Khóa học: IT_209 - Quản trị Hệ thống Linux / DevOps Foundation
# Session: 07 - Bài 1 (ex1)
# ==============================================================================

set -euo pipefail

# Màu hiển thị console
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}    KHỞI TẠO TÀI KHOẢN GIỚI HẠN VÀ THIẾT LẬP SFTP LOG SERVER                  ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

# 1. Kiểm tra đặc quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Vui lòng chạy script này với quyền root hoặc sử dụng sudo!${NC}"
    exit 1
fi

SFTP_USER="sftp-user"
SFTP_PASS="Sftp@Secure2026!LogAccess"
LOG_DIR="/var/log/app-backup"
LOG_FILE="${LOG_DIR}/backup-check.log"

# 2. Tạo người dùng sftp-user nếu chưa tồn tại
echo -e "\n${YELLOW}[1/5] Khởi tạo tài khoản người dùng: ${SFTP_USER}...${NC}"
if id "$SFTP_USER" >/dev/null 2>&1; then
    echo -e "[-] Người dùng '${SFTP_USER}' đã tồn tại trên hệ thống."
else
    # Tạo user hệ thống có thư mục home và shell tiêu chuẩn
    useradd -m -s /bin/bash "$SFTP_USER"
    echo -e "${GREEN}✓ Đã tạo người dùng '${SFTP_USER}' thành công.${NC}"
fi

# Thiết lập mật khẩu mạnh
echo "${SFTP_USER}:${SFTP_PASS}" | chpasswd
echo -e "${GREEN}✓ Đã cập nhật mật khẩu bảo mật mạnh cho user '${SFTP_USER}'.${NC}"

# Đảm bảo user KHÔNG thuộc nhóm sudo/wheel
if groups "$SFTP_USER" | grep -E '\b(sudo|wheel|admin)\b' >/dev/null 2>&1; then
    echo -e "${YELLOW}[!] Phát hiện user '${SFTP_USER}' thuộc nhóm quản trị, đang tiến hành gỡ bỏ...${NC}"
    gpasswd -d "$SFTP_USER" sudo 2>/dev/null || true
    gpasswd -d "$SFTP_USER" wheel 2>/dev/null || true
    gpasswd -d "$SFTP_USER" admin 2>/dev/null || true
fi
echo -e "${GREEN}✓ Đã xác nhận '${SFTP_USER}' là non-root/non-sudo user (Least Privilege).${NC}"

# 3. Tạo thư mục log giả lập
echo -e "\n${YELLOW}[2/5] Tạo thư mục nhật ký sao lưu: ${LOG_DIR}...${NC}"
mkdir -p "$LOG_DIR"
echo -e "${GREEN}✓ Thư mục '${LOG_DIR}' đã sẵn sàng.${NC}"

# 4. Khởi tạo tệp log giả lập
echo -e "\n${YELLOW}[3/5] Khởi tạo tệp log: ${LOG_FILE}...${NC}"
cat << EOF > "$LOG_FILE"
Backup status: SUCCESS at $(date -u '+%a %b %e %T UTC %Y')
[$(date -u '+%Y-%m-%d %T UTC')] Starting automated database backup: db_production_20261006.sql.gz
[$(date -u '+%Y-%m-%d %T UTC')] Database dump completed successfully. Size: 42.8 MB
[$(date -u '+%Y-%m-%d %T UTC')] Compressing static assets: assets_backup_20261006.tar.gz
[$(date -u '+%Y-%m-%d %T UTC')] Assets compression completed. Size: 154.2 MB
[$(date -u '+%Y-%m-%d %T UTC')] Verifying data integrity and generating SHA-256 checksums...
[$(date -u '+%Y-%m-%d %T UTC')] Checksum verification: PASSED (sha256: 7d1f568a83d73359d877e8a329ef31238bf3bbf893e481b37df43e4142750e29)
[$(date -u '+%Y-%m-%d %T UTC')] Storage target: /var/log/app-backup/
[$(date -u '+%Y-%m-%d %T UTC')] Retention policy: 14 days retained. Expired backups pruned: 0
[$(date -u '+%Y-%m-%d %T UTC')] Backup status: SUCCESS - All tasks finished without errors.
EOF
echo -e "${GREEN}✓ Đã tạo và ghi nội dung giả lập vào '${LOG_FILE}'.${NC}"

# 5. Phân quyền chặt chẽ theo yêu cầu đề bài
echo -e "\n${YELLOW}[4/5] Thiết lập quyền sở hữu và phân quyền (Permissions)...${NC}"
# Gán chủ sở hữu là root, nhóm sở hữu là sftp-user
chown -R root:"$SFTP_USER" "$LOG_DIR"

# Thư mục: 750 (rwxr-x---) -> Root toàn quyền, sftp-user đọc & truy cập cd, Others bị cấm
chmod 750 "$LOG_DIR"

# Tệp tin log: 640 (rw-r-----) -> Root đọc/ghi, sftp-user chỉ đọc, Others bị cấm
chmod 640 "$LOG_FILE"
echo -e "${GREEN}✓ Đã phân quyền: ${LOG_DIR} (750), ${LOG_FILE} (640), Owner: root:${SFTP_USER}${NC}"

# 6. Kiểm tra trạng thái dịch vụ SSH / SFTP
echo -e "\n${YELLOW}[5/5] Kiểm tra dịch vụ SSH Server (sshd)...${NC}"
if systemctl is-active --quiet sshd || systemctl is-active --quiet ssh; then
    echo -e "${GREEN}✓ Dịch vụ SSH Server đang hoạt động bình thường trên cổng 22.${NC}"
else
    echo -e "${YELLOW}[!] Dịch vụ SSH chưa chạy. Đang khởi động...${NC}"
    systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
fi

echo -e "\n${BLUE}==============================================================================${NC}"
echo -e "${GREEN}✓ HOÀN TẤT THIẾT LẬP THÀNH CÔNG!${NC}"
echo -e "Thông tin kết nối SFTP từ máy Windows Client:"
echo -e " - Host (IP):     <Địa_chỉ_IP_của_VPS>"
echo -e " - Port:          22"
echo -e " - Username:      ${SFTP_USER}"
echo -e " - Password:      ${SFTP_PASS}"
echo -e " - Đường dẫn log: ${LOG_FILE}"
echo -e "${BLUE}==============================================================================${NC}"
