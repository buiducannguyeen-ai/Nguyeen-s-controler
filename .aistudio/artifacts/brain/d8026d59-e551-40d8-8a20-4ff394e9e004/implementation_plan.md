# Kế Hoạch Sửa Lỗi Khởi Chạy Tệp run.bat Trên Máy Tính Windows

## 1. Nguyên Nhân Gốc Rễ Khiến run.bat Gặp Lỗi
Qua phân tích chi tiết mã nguồn khởi chạy trên Windows:
1. **Lỗi thứ tự mã hóa UTF-8 trong `run.bat`**: Lệnh `title Nguyễn's AI...` chứa ký tự tiếng Việt có dấu được đặt **trước** lệnh chuyển bảng mã `chcp 65001`, khiến trình thông dịch Command Prompt (`cmd.exe`) phân tích sai mã ký tự trên các máy Windows có bảng mã mặc định ANSI (CP437/CP1252/CP1258).
2. **Khóa bảo mật tệp tải về từ Internet (Windows SmartScreen / Zone.Identifier)**: Khi giải nén tệp ZIP trên Windows, các tệp PowerShell (`.ps1`) thường bị Windows gán nhãn chặn thực thi. `run.bat` cần tự động bỏ chặn (`Unblock-File`) trước khi gọi PowerShell.
3. **Lỗi xác thực API Key (`Verify-Key`) trong `NguyeensCLI.ps1`**: Hàm `Verify-Key` hiện tại gửi POST request gọi model cố định qua REST API. Nếu mô hình trả về mã lỗi 404/400 thì khóa API hợp lệ vẫn bị báo lỗi và vòng lặp nhập khóa không thoát được. Cần chuyển sang phương thức `GET /v1beta/models?key=...` chuẩn của Google AI Studio (giống như trong `NguyeensAI.ps1`).
4. **Lỗi ngắt đối số câu lệnh có dấu cách khi gọi `worker.ps1`**: Trong `NguyeensCLI.ps1`, câu lệnh được truyền qua `-TaskText $trimmed` không bọc tệp JSON, khiến PowerShell tách các từ có dấu cách (ví dụ "mở notepad") thành nhiều tham số không hợp lệ và báo lỗi tham số.
5. **Ngoại lệ chưa bắt trong `Get-Secret` của `worker.ps1`**: Khi `secret.txt` chưa tồn tại hoặc bị khóa, lệnh đọc ném ra ngoại lệ dừng chương trình thay vì kiểm tra tệp an toàn.

---

## 2. Các Bước Thực Hiện Chi Tiết

### Bước 1: Tối Ưu Hóa `run.bat`
- Đặt `chcp 65001 >nul 2>&1` ngay sau `@echo off` trước mọi chuỗi tiếng Việt.
- Bổ sung lệnh tự động bỏ chặn tập tin: `powershell.exe -NoLogo -NoProfile -Command "Get-ChildItem -Path '%~dp0' -Recurse | Unblock-File -ErrorAction SilentlyContinue" >nul 2>&1`.
- Bọc đường dẫn PowerShell chính xác với cờ `-ExecutionPolicy Bypass`.
- Giữ thông báo lỗi rõ ràng nếu có sự cố xảy ra kèm `pause` để người dùng đọc được thông báo.

### Bước 2: Khắc Phục Lỗi Trong `NguyeensCLI.ps1`
- Chuyển `Verify-Key` sang kiểm tra endpoint `https://generativelanguage.googleapis.com/v1beta/models?key=$Key` bằng giao thức TLS 1.2 an toàn, đảm bảo mọi API key của Google AI Studio đều được xác nhận tức thì.
- Thay vì truyền `-TaskText` trực tiếp qua dòng lệnh dễ vướng lỗi ký tự khoảng trắng tiếng Việt, ghi nhiệm vụ vào `data/task.json` với chuẩn UTF-8 rồi truyền `-TaskPath "$taskPath"`.

### Bước 3: Tăng Cường Độ Bền Cho `worker.ps1`
- Trong `Get-Secret`: kiểm tra `Test-Path $path` trước khi đọc; nếu không có tệp bí mật thì kiểm tra `$env:GEMINI_API_KEY`, nếu vẫn trống thì hiển thị thông báo hướng dẫn dễ hiểu thay vì crash script.
- Kiểm tra loại kiểu C# `NguyeensNativeInput` trước khi gọi `Add-Type` để tránh lỗi "Type already exists" khi chạy liên tục nhiều phiên.

### Bước 4: Đồng Bộ Hóa Hệ Thống Gói Tải Về
- Đồng bộ toàn bộ nội dung sửa đổi vào thư mục `nguyeens-ai-gemini/` và `src/data/packageFiles.ts`.
- Đảm bảo endpoint `/api/download-zip` tạo tệp ZIP với đầy đủ bảng mã và cấu trúc tệp mới nhất.
- Biên dịch lại dự án với `compile_applet` để xác thực không có lỗi lint hay build.

---

## 3. Tiêu Chí Nghiệm Thu (Verification Checklist)
- [ ] Chạy `run.bat` trên Windows khởi động Command Prompt mượt mà, không lỗi bảng mã hay ký tự lạ.
- [ ] Nhập API key hợp lệ được chấp nhận ngay lập tức mà không báo lỗi 404.
- [ ] Nhập nhiệm vụ có khoảng trắng và dấu tiếng Việt (ví dụ: "mở trình duyệt và tìm kiếm") chuyển giao mượt sang `worker.ps1`.
- [ ] Dự án web biên dịch thành công (`compile_applet`), tệp ZIP tải về chứa đầy đủ mã nguồn cập nhật.
