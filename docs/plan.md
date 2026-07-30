# 1) Mục tiêu sản phẩm

Build 1 app nhỏ chạy trên **menu bar macOS** để hiển thị:

## Mục tiêu chính

- **5-hour quota usage**
- **weekly quota usage**
- **reset time**
- **current session token usage** _(nếu lấy được)_
- **trạng thái realtime / gần realtime**

## Mục tiêu UX

- Nhìn nhanh ngay trên menu bar
- Bấm vào thì mở popup xem chi tiết
- Nhẹ, ít tốn RAM/CPU
- Tự chạy khi login
- Có setting để chọn kiểu hiển thị

---

# 2) Scope chia theo phase

---

## Phase 1 — MVP

Mục tiêu: có app chạy được, hiển thị quota Codex trên menu bar.

### Tính năng

- Menu bar app icon + text
- Gọi `codex app-server`
- Lấy:
    - `primary usage` (5h)
    - `secondary usage` (weekly)
    - `reset time`

- Hiển thị:
    - Trên thanh top: `C 24%`
    - Hoặc `5H 24% | W 61%`

- Dropdown popup:
    - 5h usage
    - weekly usage
    - reset countdown
    - last updated
    - refresh button

- Setting:
    - launch at login
    - refresh interval fallback
    - compact mode / detailed mode

### Chưa làm ở phase này

- chart lịch sử
- notification vượt ngưỡng
- session token live phức tạp
- multi-account

---

## Phase 2 — Enhanced

Mục tiêu: thông minh hơn, giống “monitor app” thật sự.

### Tính năng thêm

- Current session token live:
    - input tokens
    - output tokens
    - cached tokens
    - total tokens

- Theo dõi event realtime
- Notification:
    - quota vượt 70%, 90%
    - sắp reset quota

- Mini history:
    - usage theo thời gian

- Nhiều style hiển thị:
    - icon only
    - compact text
    - progress ring

- Error state rõ ràng:
    - codex chưa login
    - app-server chết
    - không đọc được usage

---

## Phase 3 — Pro / tiện dụng hơn

Nếu bro muốn làm thành tool xài lâu dài.

### Tính năng thêm

- Dashboard window riêng
- History 7 ngày / 30 ngày
- Export log
- Theo dõi nhiều workspace / nhiều profile
- menu bar widgets khác:
    - current active task
    - request count
    - token/min
    - model đang dùng

---

# 3) Tên gọi feature / app

Một vài tên có thể dùng:

- **Codex Meter**
- **Codex Usage Bar**
- **Codex Pulse**
- **Codex Monitor**
- **Codex TopBar**

Mình thấy **Codex Meter** là gọn nhất.

---

# 4) UI/UX chi tiết

---

## 4.1. Menu bar hiển thị

Nên có 3 mode:

### Mode A — minimal

```txt
C 24%
```

### Mode B — useful

```txt
5H 24%  W 61%
```

### Mode C — compact mixed

```txt
⌁ 24% / 61%
```

### Đề xuất mặc định

- mặc định dùng: `5H 24%  W 61%`
- nếu menu bar chật: auto chuyển `C 24%`

---

## 4.2. Popup khi bấm vào

### Section 1 — Header

- App name: **Codex Meter**
- trạng thái:
    - Connected
    - Refreshing
    - Error

### Section 2 — Quota

- 5-hour usage
    - progress bar
    - percent
    - reset in Xh Ym

- Weekly usage
    - progress bar
    - percent
    - reset day/time

### Section 3 — Session

- Current session tokens
- Input
- Output
- Cached
- Total

### Section 4 — Controls

- Refresh now
- Open settings
- Restart connection
- Quit

---

## 4.3. Settings screen

### Tab General

- Launch at login
- Show icon in dock: on/off
- Show notification: on/off

### Tab Display

- Menu bar mode:
    - icon only
    - minimal
    - full

- Use color warning:
    - green < 60%
    - yellow 60–85%
    - red > 85%

- Show weekly usage on bar: on/off

### Tab Data

- Auto refresh interval fallback:
    - 15s
    - 30s
    - 60s

- Enable realtime subscription
- Session token tracking: on/off

### Tab Debug

- View raw JSON response
- Logs
- Restart codex app-server

---

# 5) Kiến trúc kỹ thuật

---

## 5.1. Stack

- **Swift**
- **SwiftUI**
- **MenuBarExtra**
- **AppKit** _(nếu cần custom sâu hơn)_
- **Foundation**
- **Process + Pipe**
- **async/await**
- **UserDefaults**
- **SMAppService** _(launch at login)_

---

## 5.2. Kiến trúc module

```txt
CodexMeterApp
│
├── App
│   ├── CodexMeterApp.swift
│   └── AppState.swift
│
├── UI
│   ├── MenuBarView.swift
│   ├── PopupView.swift
│   ├── SettingsView.swift
│   ├── UsageRowView.swift
│   └── StatusBadgeView.swift
│
├── Services
│   ├── CodexServerManager.swift
│   ├── CodexRPCClient.swift
│   ├── UsagePollingService.swift
│   ├── SessionTrackerService.swift
│   └── NotificationService.swift
│
├── Models
│   ├── RateLimitModels.swift
│   ├── SessionUsageModels.swift
│   ├── SettingsModels.swift
│   └── AppStatusModels.swift
│
├── Utils
│   ├── DateFormatterHelper.swift
│   ├── CountdownFormatter.swift
│   ├── Logger.swift
│   └── JSONRPC.swift
│
└── Storage
    ├── SettingsStore.swift
    └── HistoryStore.swift
```

---

## 5.3. Luồng dữ liệu

```txt
Menu bar app launch
    ↓
Start CodexServerManager
    ↓
Spawn `codex app-server`
    ↓
Initialize JSON-RPC session
    ↓
Read account/rateLimits
    ↓
Subscribe account/rateLimits/updated
    ↓
Update AppState
    ↓
Render menu bar + popup
```

Nếu realtime event không ổn:

```txt
Fallback polling mỗi 30s
```

---

# 6) Data source chi tiết

---

## 6.1. Primary source

App sẽ giao tiếp với:

```bash
codex app-server --listen stdio://
```

### RPC cần dùng ở MVP

- `initialize`
- `account/rateLimits/read`

### RPC / event nên dùng tiếp

- `account/rateLimits/updated`
- `account/usage/read` _(nếu cần extra info)_
- session/token events _(nếu exposed được)_

---

## 6.2. Dữ liệu cần normalize

### Raw input

Có thể sẽ trả kiểu:

- `usedPercent`
- `windowDurationMins`
- `resetsAt`

### Model nội bộ

```swift
struct UsageWindow {
    let name: String            // "5-hour" / "weekly"
    let usedPercent: Double
    let resetsAt: Date
    let durationMinutes: Int
}
```

### App state tổng

```swift
struct UsageState {
    var primary: UsageWindow?
    var secondary: UsageWindow?
    var session: SessionUsage?
    var lastUpdated: Date?
    var connectionStatus: ConnectionStatus
}
```

---

# 7) Logic vận hành

---

## 7.1. Khởi động app

- check `codex` có cài chưa
- check có access được `codex app-server` không
- nếu không:
    - show error state
    - nút “Open setup guide”

---

## 7.2. Kết nối

- app spawn subprocess
- tạo `stdin/stdout pipe`
- gửi request `initialize`
- sau đó gọi `account/rateLimits/read`

---

## 7.3. Cập nhật

### Normal path

- lắng nghe event update
- nếu có thay đổi -> update UI ngay

### Fallback path

- polling 30 giây / 60 giây nếu event không tới

---

## 7.4. Error handling

Các case cần xử lý:

- `codex` chưa cài
- `codex` chưa login
- subprocess crash
- JSON parse lỗi
- timeout
- network/auth issue

### Trạng thái UI

- Connected
- Syncing
- Warning
- Error

---

# 8) Session usage realtime

Phần này nên làm **sau MVP** vì có thể phức tạp hơn quota account.

## Dữ liệu mong muốn

- input tokens
- output tokens
- cached tokens
- total tokens
- active model
- current task name _(nếu có)_

## Cách làm

### Option A — chính thống

Đọc qua event/app-server nếu nó expose.

### Option B — fallback

Parse từ log/session metadata local của Codex nếu có.

### Option C — tạm thời

Chưa hiển thị live token, chỉ hiển thị account quota.

### Đề xuất

- **Phase 1: bỏ qua**
- **Phase 2: thêm**

---

# 9) Thiết kế cảnh báo màu

Để nhìn nhanh giống monitor app:

## Usage level

- **0–59%**: bình thường
- **60–84%**: cảnh báo nhẹ
- **85%+**: nguy cơ sắp hết quota

## Hiển thị

- bar màu nhẹ
- text giữ clean
- tránh màu quá gắt trên menu bar

---

# 10) Performance target

Mục tiêu app nhẹ như mấy app monitor system.

## Performance goal

- RAM: **< 60MB**
- CPU idle: **~0%**
- Refresh không spam
- Không làm menu bar lag

## Tối ưu

- subscribe event thay vì polling nhiều
- nếu polling thì 30s là đủ
- không render UI liên tục nếu data không đổi

---

# 11) Security / stability

## Lưu ý

- không hardcode credential
- không lấy cookie browser
- không gọi web scraping
- dùng đúng `codex app-server`
- log debug phải có thể tắt

## Stability

- nếu app-server chết -> auto reconnect
- giới hạn retry:
    - lần 1 sau 2s
    - lần 2 sau 5s
    - lần 3 sau 10s
    - max backoff 60s

---

# 12) Roadmap triển khai theo task

---

## Milestone 1 — Project bootstrap

### Việc cần làm

- tạo Xcode project
- setup menu bar app
- ẩn dock icon
- tạo popup UI đơn giản

### Deliverable

- app menu bar hiện “Codex Meter”
- click mở popup được

---

## Milestone 2 — Codex connection layer

### Việc cần làm

- viết `CodexServerManager`
- spawn subprocess
- setup stdin/stdout pipe
- gửi `initialize`
- parse response

### Deliverable

- app connect được tới codex app-server
- show trạng thái connected / error

---

## Milestone 3 — Quota usage fetch

### Việc cần làm

- implement `account/rateLimits/read`
- map data sang model nội bộ
- render 5h / weekly usage

### Deliverable

- popup hiện usage thật
- menu bar hiện text usage

---

## Milestone 4 — Realtime updates + fallback polling

### Việc cần làm

- subscribe update event
- thêm polling dự phòng
- debounce update UI

### Deliverable

- usage tự update không cần restart app

---

## Milestone 5 — Settings

### Việc cần làm

- launch at login
- display mode
- refresh interval
- warning notification toggle

### Deliverable

- có settings dùng được

---

## Milestone 6 — Session usage

### Việc cần làm

- nghiên cứu event token/session
- parse session data
- thêm UI section Current Session

### Deliverable

- token live / gần live trong popup

---

## Milestone 7 — Polish

### Việc cần làm

- icon đẹp
- animation nhẹ
- error message dễ hiểu
- debug logs
- reconnect mượt

### Deliverable

- app đủ sạch để dùng hàng ngày

---

# 13) Timeline đề xuất

## Nếu làm nhanh theo MVP

### Ngày 1

- bootstrap project
- làm menu bar UI
- popup UI cơ bản

### Ngày 2

- làm `codex app-server` integration
- initialize + fetch rate limits

### Ngày 3

- render data thật
- menu bar modes
- error handling cơ bản

### Ngày 4

- realtime update + polling fallback
- settings cơ bản

### Ngày 5

- test thực tế
- fix bug
- build bản dùng hàng ngày

=> **5 ngày là có bản MVP khá ổn**

---

## Nếu làm full hơn

- MVP: 4–5 ngày
- Enhanced: thêm 3–5 ngày
- Polish: thêm 2–3 ngày

=> tổng khoảng **1.5–2 tuần** cho bản ngon.

---

# 14) Rủi ro kỹ thuật

## Rủi ro 1

`codex app-server` thay đổi schema response

### Giải pháp

- bọc parser cẩn thận
- version guard
- raw JSON debug view

## Rủi ro 2

event realtime không ổn định

### Giải pháp

- fallback polling

## Rủi ro 3

session token data khó lấy

### Giải pháp

- đưa vào phase 2
- bản MVP chỉ cần quota usage trước

## Rủi ro 4

menu bar quá chật

### Giải pháp

- hỗ trợ 3 mode hiển thị

---

# 15) Định nghĩa Done cho MVP

MVP được coi là xong khi:

- app chạy trên macOS
- nằm ở menu bar
- đọc được quota thật của Codex
- hiển thị:
    - 5h usage
    - weekly usage
    - reset time

- click mở popup chi tiết
- có refresh
- có launch at login
- có error state rõ ràng

---

# 16) Đề xuất hướng làm thực tế

Mình khuyên bro làm theo thứ tự:

## Step 1

**Chỉ làm quota account trước**

- 5h
- weekly
- reset

## Step 2

Làm UI đẹp + settings

## Step 3

Sau khi ổn định mới thêm:

- session token live
- history
- notification

Lý do:

- phần quota account dễ chốt sớm
- có sản phẩm usable ngay
- session token live là phần dễ phát sinh kỹ thuật hơn

---

# 17) Gợi ý output menu bar mặc định

Mình đề xuất bản đầu:

## Menu bar

```txt
5H 24%  W 61%
```

## Popup

```txt
Codex Meter
Connected

5-hour usage     24%
Resets in        2h 18m

Weekly usage     61%
Resets on        Mon 09:00

Last updated     11:42:08

[Refresh] [Settings] [Quit]
```

Đây là bản vừa đủ đẹp, ít rối, dễ build.

---

# 18) Nếu bro muốn bắt tay code ngay

Bước tiếp theo hợp lý nhất là mình viết cho bro:

## Option A

**spec kỹ thuật đầy đủ cho dev**

- class nào làm gì
- flow JSON-RPC
- state management
- UI state
- error cases

## Option B

**scaffold code luôn**

- Xcode project structure
- `CodexMeterApp.swift`
- `CodexServerManager.swift`
- `CodexRPCClient.swift`
- `MenuBarView.swift`
- `PopupView.swift`

## Option C

**vẽ wireframe UI**

- menu bar
- popup
- settings

---
