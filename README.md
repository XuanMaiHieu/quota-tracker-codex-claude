# Codex Meter

App menu bar macOS hiển thị quota **Codex CLI** (5-hour / weekly usage, reset time, đọc trực tiếp từ `codex app-server`) và **Claude Code** (5-hour / 7-day usage, đọc từ endpoint `oauth/usage` bằng chính OAuth token của Claude Code). Xem chi tiết thiết kế ở [`docs/plan.md`](docs/plan.md).

Quota Claude Code lấy được nếu bạn đã đăng nhập `claude` CLI trên máy (token đọc từ Keychain "Claude Code-credentials", hoặc từ `~/.claude/.credentials.json` nếu không dùng Keychain). Nếu chưa đăng nhập, phần Claude trong popup sẽ báo lỗi "not logged in" thay vì crash.

## Yêu cầu trước khi cài

- macOS 13 trở lên
- [Codex CLI](https://github.com/openai/codex) đã cài và đã đăng nhập (`codex login`)
- Xcode Command Line Tools / Swift toolchain (để build) — kiểm tra bằng `swift --version`

## Cài đặt (1 lệnh)

```bash
./install.sh
```

Lệnh này sẽ:

1. Build bản release (`swift build -c release`)
2. Đóng gói thành `CodexMeter.app` (có `Info.plist` với `LSUIElement=true` để ẩn Dock icon)
3. Copy vào `/Applications/CodexMeter.app`
4. Mở app ngay — icon quota sẽ xuất hiện trên menu bar

Muốn cập nhật sau khi sửa code: chạy lại `./install.sh` là đủ (tự build lại và thay app cũ).

## Quyền cần cấp

Về cơ bản **không cần cấp quyền riêng** (không đụng Accessibility, Camera, Mic, Full Disk Access...). Có 2 điều cần biết:

- **Gatekeeper (lần mở đầu tiên)**: app build local nên thường không bị chặn. Nếu macOS báo *"không thể xác minh nhà phát triển"* (thường chỉ xảy ra khi app bị gắn cờ quarantine, ví dụ tải qua trình duyệt): chuột phải vào `CodexMeter.app` → **Open**, hoặc vào **System Settings → Privacy & Security** bấm **Open Anyway**.
- **Login Items**: app tự động bật **"Launch at login"** ngay lần chạy đầu tiên (không cần bạn bấm gì), nên nó sẽ tự khởi động cùng macOS mỗi khi bạn đăng nhập máy. macOS chỉ hiện 1 thông báo hệ thống báo "đã thêm login item", không yêu cầu nhập mật khẩu admin. Muốn tắt: mở popup app → **Settings → General**, hoặc **System Settings → General → Login Items**.
- **Keychain (chỉ để đọc quota Claude Code)**: lần đầu app đọc token từ mục Keychain `"Claude Code-credentials"`, macOS sẽ hiện 1 hộp thoại hỏi *"CodexMeter wants to use your confidential information..."* — bấm **Allow** (hoặc **Always Allow** để khỏi hỏi lại). App chỉ đọc access token để gọi API usage, không ghi/sửa gì vào Keychain.

## Sử dụng

- Bấm icon trên menu bar để xem popup chi tiết (5h/weekly usage, reset time, last updated)
- **Refresh**: lấy quota mới ngay
- **Settings**: đổi kiểu hiển thị menu bar (Minimal/Useful/Compact), refresh interval, bật/tắt launch at login

## Gỡ cài đặt

```bash
pkill -f /Applications/CodexMeter.app/Contents/MacOS/CodexMeter
rm -rf /Applications/CodexMeter.app
```

Nếu đã bật launch at login, vào **System Settings → General → Login Items** để xóa nốt mục "Codex Meter" (macOS đôi khi để lại entry sau khi xóa thẳng app bundle).

## Build/chạy khi phát triển (không cần cài vào /Applications)

```bash
swift build          # build debug
swift run            # chạy trực tiếp (hiện icon Dock vì chưa đóng gói .app)
./Scripts/bundle-app.sh   # đóng gói .build/CodexMeter.app để test LSUIElement/launch-at-login
```
