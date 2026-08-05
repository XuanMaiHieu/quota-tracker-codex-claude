# Codex Meter

App menu bar macOS hiển thị quota **Codex CLI** (5-hour / weekly usage, reset time, đọc trực tiếp từ `codex app-server`) và **Claude Code** (5-hour / 7-day usage, đọc từ endpoint `oauth/usage` bằng chính OAuth token của Claude Code). Xem chi tiết thiết kế ở [`docs/plan.md`](docs/plan.md).

Trên menu bar, mỗi provider hiện 1 badge màu riêng (Codex xanh teal, Claude Code cam) với 2 ô **5H** / **W** (5-hour và weekly/7-day) và % đã dùng bên dưới, màu chữ % đổi theo mức dùng (xanh → cam → đỏ khi gần hết quota). Nếu chưa fetch được dữ liệu, ô đó hiện `--`.

Quota Claude Code lấy được nếu bạn đã đăng nhập `claude` CLI trên máy (token đọc từ Keychain "Claude Code-credentials", hoặc từ `~/.claude/.credentials.json` nếu không dùng Keychain). Nếu chưa đăng nhập, phần Claude trong popup sẽ báo lỗi "not logged in" thay vì crash.

## Yêu cầu trước khi cài

- macOS 13 trở lên
- [Codex CLI](https://github.com/openai/codex) đã cài và đã đăng nhập (`codex login`) — cần cho phần quota Codex; nếu không có, app vẫn chạy được và chỉ hiện quota Claude Code
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
- **Keychain (chỉ để đọc quota Claude Code)**: lần đầu app đọc token từ mục Keychain `"Claude Code-credentials"`, macOS sẽ hiện 1 hộp thoại hỏi *"CodexMeter wants to use your confidential information..."* — bấm **Always Allow**. App chỉ đọc access token để gọi API usage, không ghi/sửa gì vào Keychain.
  - Nếu bạn thấy hộp thoại này **hiện lại mỗi lần build**, xem mục [Code signing](#code-signing-để-macos-nhớ-always-allow-giữa-các-lần-build) bên dưới.

## Sử dụng

- Menu bar hiện badge màu cho từng provider đang bật (5H / W / %). Bấm vào badge để mở popup chi tiết: usage %, thời điểm reset (`Resets in` cho 5-hour, `Resets on` cho weekly/7-day), thời điểm cập nhật gần nhất.
- **Refresh**: lấy quota mới ngay cho cả 2 provider.
- **Settings**:
  - *General* — bật/tắt Launch at login
  - *Display* — bật/tắt hiện Codex và/hoặc Claude Code trên menu bar (tắt cả 2 thì menu bar chỉ hiện "Quota off")
  - *Data* — refresh interval (15s / 30s / 60s)

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

## Code signing (để macOS nhớ "Always Allow" giữa các lần build)

`Scripts/bundle-app.sh` build xong sẽ tự `codesign` app bằng một identity cố định. Lý do: macOS Keychain nhớ quyền "Always Allow" dựa trên chữ ký code của app — nếu app không được ký (hoặc ký ad-hoc ngẫu nhiên mỗi lần build), mỗi lần rebuild macOS sẽ coi đó là "app khác" và bắt xác nhận mật khẩu lại từ đầu mỗi khi app đọc Keychain (`"Claude Code-credentials"`).

Vì đây là certificate tự ký, **mỗi người tự tạo certificate riêng trên máy mình** (không share certificate qua git — private key không nên rời máy, và Keychain ACL vốn cũng chỉ có tác dụng trên máy đó):

1. Mở **Keychain Access** → menu **Keychain Access → Certificate Assistant → Create a Certificate...**
2. Điền:
   - **Name**: tuỳ ý, ví dụ `<TênBạn> CodexMeter Signing`
   - **Identity Type**: `Self Signed Root`
   - **Certificate Type**: `Code Signing`
3. Bấm **Create** → **Continue** đến hết → **Done**.
4. Trong Keychain Access, tìm certificate vừa tạo (mục **My Certificates**, keychain **login**), double-click → mở rộng **Trust** → đổi **Code Signing** thành **Always Trust** → đóng và nhập mật khẩu máy để xác nhận.
5. Copy `.env.example` thành `.env` và điền đúng tên certificate:
   ```bash
   cp .env.example .env
   # sửa .env: CODEXMETER_SIGN_IDENTITY="<TênBạn> CodexMeter Signing"
   ```

`.env` đã nằm trong `.gitignore` nên không ai bị dính tên identity của người khác. `Scripts/bundle-app.sh` tự đọc `.env` nếu có; nếu không có `.env`, script fallback dùng tên mặc định `CodexMeter Local Signing`.

Sau khi setup xong, `./install.sh` (hoặc `./Scripts/bundle-app.sh`) sẽ tự ký bằng identity của bạn ở mỗi lần build. Lần đầu tiên sau khi đổi sang identity mới, macOS sẽ hỏi Keychain 1 lần — bấm **Always Allow**, từ đó về sau sẽ không hỏi lại nữa vì chữ ký không đổi giữa các lần build.

## Cấu trúc project

```
Sources/CodexMeter/
├── App/                  Entry point (CodexMeterApp: MenuBarExtra) + AppState (nguồn dữ liệu chung)
├── Models/                Kiểu dữ liệu: rate-limit/usage windows, Claude usage wire format, settings, status
├── Services/
│   ├── CodexServerManager     Spawn & quản lý tiến trình con `codex app-server` (stdio JSON-RPC)
│   ├── CodexRPCClient         Client JSON-RPC nói chuyện với app-server
│   ├── UsagePollingService    Gọi RPC lấy rate limit từ Codex
│   └── ClaudeUsageService     Đọc OAuth token từ Keychain/credentials file, gọi thẳng oauth/usage của Claude
├── Storage/               SettingsStore (UserDefaults-backed, đồng bộ 2 chiều với SettingsView)
├── UI/
│   ├── MenuBarBadge.swift     View render offscreen thành NSImage cho menu bar (badge màu theo provider)
│   ├── MenuBarView.swift      MenuBarLabel: gom dữ liệu 2 provider và gọi ImageRenderer
│   ├── PopupView.swift        Popup khi bấm vào menu bar
│   ├── UsageRowView.swift     1 dòng usage (progress bar + % + reset time) trong popup
│   ├── StatusBadgeView.swift  Badge trạng thái kết nối (connecting/connected/error)
│   └── SettingsView.swift / SettingsWindowController.swift   Cửa sổ Settings (General/Display/Data)
├── Utils/                 CountdownFormatter, UsageColor (màu theo % dùng), AppLogo, JSONRPC, Logger
└── Resources/              codex-logo.png, claude-logo.png (hiện trong popup)
```

Codex và Claude Code là hai nguồn dữ liệu độc lập trong `AppState`: mất kết nối Codex (ví dụ CLI chưa cài) không ảnh hưởng tới việc fetch quota Claude Code và ngược lại.
