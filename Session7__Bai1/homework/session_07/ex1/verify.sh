#!/usr/bin/env bash
# ==============================================================================
# Script: verify.sh
# Mục đích: Kiểm thử toàn diện tài khoản sftp-user, phân quyền tệp tin và an ninh
# Khóa học: IT_209 - Quản trị Hệ thống Linux / DevOps Foundation
# Session: 07 - Bài 1 (ex1)
# ==============================================================================

set -uo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}    KIỂM TRA HỆ THỐNG & ĐÁNH GIÁ AN NINH CHO BÀI 1 (SFTP USER)                ${NC}"
echo -e "${BLUE}==============================================================================${NC}"

SFTP_USER="sftp-user"
LOG_DIR="/var/log/app-backup"
LOG_FILE="${LOG_DIR}/backup-check.log"
ALL_PASSED=1

# 1. Kiểm tra sự tồn tại của người dùng
echo -e "\n${YELLOW}[Kiểm tra 1/5] Kiểm tra người dùng '${SFTP_USER}'...${NC}"
if id "$SFTP_USER" >/dev/null 2>&1; then
    ID_OUT=$(id "$SFTP_USER")
    echo -e "${GREEN}✓ Người dùng tồn tại:${NC} ${ID_OUT}"
else
    echo -e "${RED}✗ LỖI: Người dùng '${SFTP_USER}' không tồn tại!${NC}"
    ALL_PASSED=0
fi

# 2. Kiểm tra ràng buộc đặc quyền (Không được thuộc nhóm sudo/wheel)
echo -e "\n${YELLOW}[Kiểm tra 2/5] Đảm bảo '${SFTP_USER}' KHÔNG có quyền sudo (Least Privilege)...${NC}"
USER_GROUPS=$(groups "$SFTP_USER" 2>/dev/null || echo "")
if echo "$USER_GROUPS" | grep -E '\b(sudo|wheel|admin)\b' >/dev/null 2>&1; then
    echo -e "${RED}✗ CẢNH BÁO AN NINH: User '${SFTP_USER}' đang thuộc nhóm đặc quyền (${USER_GROUPS})!${NC}"
    ALL_PASSED=0
else
    echo -e "${GREEN}✓ ĐẠT CHUẨN: User '${SFTP_USER}' không thuộc bất kỳ nhóm quản trị nào (${USER_GROUPS}).${NC}"
fi

# 3. Kiểm tra phân quyền thư mục và tệp tin
echo -e "\n${YELLOW}[Kiểm tra 3/5] Kiểm tra phân quyền thư mục và tệp tin log...${NC}"
if [ -d "$LOG_DIR" ]; then
    DIR_PERM=$(ls -ld "$LOG_DIR")
    echo -e " - Thư mục: ${DIR_PERM}"
else
    echo -e "${RED}✗ Thư mục '${LOG_DIR}' không tồn tại!${NC}"
    ALL_PASSED=0
fi

if [ -f "$LOG_FILE" ]; then
    FILE_PERM=$(ls -l "$LOG_FILE")
    echo -e " - Tệp tin: ${FILE_PERM}"
else
    echo -e "${RED}✗ Tệp tin '${LOG_FILE}' không tồn tại!${NC}"
    ALL_PASSED=0
fi

# 4. Kiểm thử khả năng đọc file log của sftp-user
echo -e "\n${YELLOW}[Kiểm tra 4/5] Kiểm thử quyền ĐỌC file log của '${SFTP_USER}'...${NC}"
if su - "$SFTP_USER" -c "cat '$LOG_FILE'" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ THÀNH CÔNG: User '${SFTP_USER}' có thể đọc nội dung file log.${NC}"
    echo "--- 3 dòng đầu của file log đọc bởi '${SFTP_USER}': ---"
    su - "$SFTP_USER" -c "head -n 3 '$LOG_FILE'"
else
    echo -e "${RED}✗ THẤT BẠI: User '${SFTP_USER}' không thể đọc file log!${NC}"
    ALL_PASSED=0
fi

# 5. Kiểm thử an ninh: sftp-user KHÔNG được phép sửa/ghi file log
echo -e "\n${YELLOW}[Kiểm tra 5/5] Kiểm thử an ninh: '${SFTP_USER}' không được phép ghi đè/sửa file log...${NC}"
if su - "$SFTP_USER" -c "echo 'Malicious data' >> '$LOG_FILE'" >/dev/null 2>&1; then
    echo -e "${RED}✗ NGUY HIỂM: User '${SFTP_USER}' có quyền ghi vào file log (Vi phạm tính toàn vẹn)!${NC}"
    ALL_PASSED=0
else
    echo -e "${GREEN}✓ AN TOÀN: Thao tác ghi bị từ chối (Permission denied). Tính toàn vẹn của log được bảo vệ.${NC}"
fi

# Tổng kết
echo -e "\n${BLUE}==============================================================================${NC}"
if [ "$ALL_PASSED" -eq 1 ]; then
    echo -e "${GREEN}✓ TẤT CẢ CÁC BƯỚC KIỂM TRA ĐÃ ĐẠT CHUẨN YÊU CẦU ĐỀ BÀI!${NC}"
    echo -e "Hệ thống sẵn sàng cho việc truyền tải qua SFTP Client từ máy Windows."
else
    echo -e "${RED}✗ CÒN LỖI CẦN KHẮC PHỤC TRƯỚC KHI NỘP BÀI!${NC}"
fi
echo -e "${BLUE}==============================================================================${NC}"
