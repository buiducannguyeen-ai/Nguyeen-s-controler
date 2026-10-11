# Universal Multi-Language Support & Laser-Accurate Mouse Grounding

Nâng cấp hệ thống tự động hóa desktop của Nguyen's AI để hỗ trợ phản hồi bằng mọi ngôn ngữ theo câu lệnh người dùng, đồng thời giải quyết triệt để lỗi lệch con trỏ chuột (suy nghĩ một đằng nhưng chuột nhấp một nẻo) thông qua đồng bộ DPI đa màn hình và chuỗi suy luận neo tọa độ thị giác.

### User Review & Critical Decisions

> [!IMPORTANT]
> Dựa trên lựa chọn của bạn trong bước làm rõ yêu cầu, hệ thống sẽ tự động điều chỉnh theo các quyết định sau:

- **Confirmed Decision 1 (Ngôn ngữ phản hồi)**: AI tự động phát hiện ngôn ngữ của câu lệnh người dùng (Tiếng Việt, Tiếng Anh, Tiếng Nhật, Tiếng Trung, Tiếng Pháp,...) để xuất `thought` và `result` tương ứng, loại bỏ ràng buộc cứng chỉ dùng Tiếng Việt trước đây.
- **Confirmed Decision 2 (Độ chính xác con trỏ chuột)**: Kết hợp giải pháp kép — vừa tính toán bù trừ tỷ lệ co giãn DPI màn hình Windows (100% - 200%), vừa áp dụng cơ chế chuỗi suy luận neo tọa độ (Thought-Coordinate Grounding CoT) để đảm bảo tọa độ click thực tế luôn trùng khớp 100% với mục tiêu trong suy nghĩ của AI.

---

### 1. Overview & Core Concept

- **Mục tiêu**: Người dùng ở bất kỳ quốc gia nào hoặc sử dụng bất kỳ ngôn ngữ nào (tiếng Việt, tiếng Anh, v.v.) đều nhận được nhật ký suy nghĩ và kết quả hoàn thành bằng ngôn ngữ đó. Khi AI quan sát màn hình và đưa ra quyết định bấm vào một nút, vị trí con trỏ chuột sẽ di chuyển chính xác tuyệt đối vào tâm của nút đó thay vì bị lệch sang vị trí khác.
- **Đối tượng sử dụng**: Người dùng chạy tác vụ tự động hóa desktop qua Web UI hoặc Command Prompt (CLI) trên Windows 10/11 với các thiết lập độ phân giải và tỷ lệ DPI khác nhau (màn hình laptop 125%/150%, màn hình rời 4K 175%/200%).
- **Giá trị cốt lõi**:
  - Giao tiếp tự nhiên, không rào cản ngôn ngữ.
  - Loại bỏ hoàn toàn hiện tượng "chuột bay lạc" hoặc nhấp trượt mục tiêu do lệch tỷ lệ màn hình hoặc hallucination tọa độ.

---

### 2. User Experience & Visual Design

- **Trải nghiệm người dùng (UX Flows)**:
  1. **Nhập câu lệnh bằng mọi ngôn ngữ**: Người dùng gõ yêu cầu bằng tiếng Anh (*"Open Chrome and search for stock price"*), tiếng Nhật, hoặc tiếng Việt (*"Giải bài tập trên màn hình"*).
  2. **Nhật ký suy nghĩ đồng nhất**: Hệ thống hiển thị dòng `Gemini: ...` trên giao diện web và màn hình console bằng chính ngôn ngữ đó, giúp người dùng theo dõi mạch tư duy của AI một cách tự nhiên.
  3. **Quan sát chuột lướt chính xác**: Khi AI quyết định *"Click the Submit button at [x, y]"*, con trỏ chuột vật lý lướt mượt mà và hạ cánh chính xác vào tâm của nút bấm trên màn hình thật, không bị lệch hoặc trượt ra vùng trống.
- **Giao diện & Chỉ báo trạng thái**:
  - Giữ nguyên giao diện retro-cyberpunk với tông màu xanh neon đen huyền bí (`#061008`, `#79ee87`).
  - Thanh trạng thái hiển thị thông tin mượt mà, hỗ trợ font chữ quốc tế UTF-8 không lỗi dấu.

---

### 3. Key Product Decisions & Trade-Offs

- **Quyết định 1: Tự động nhận diện ngôn ngữ theo ngữ cảnh prompt**:
  - *Phương án chọn*: Yêu cầu mô hình Gemini phân tích ngôn ngữ chủ đạo của `task` do người dùng gửi vào và phản hồi `thought`, `result`, giải thích bằng đúng ngôn ngữ đó. Nếu câu lệnh hỗn hợp (ví dụ gõ tiếng Việt nhưng kèm tên hàm tiếng Anh), AI sẽ phản hồi theo ngôn ngữ giao tiếp chính của người dùng.
  - *Lý do*: Tiện lợi, không bắt người dùng phải vào cài đặt đổi qua lại giữa các thứ tiếng.
- **Quyết định 2: Đồng bộ hóa tỷ lệ hiển thị vật lý (Physical Bitmap) và tọa độ ảo (Virtual Screen)**:
  - *Phương án chọn*: Khi chụp màn hình trong `Capture-Screen`, hàm sẽ ghi nhận kích thước pixel thực tế của ảnh bitmap chụp được (`ImageWidth`, `ImageHeight`) và độ phân giải hệ thống thật (`SysWidth`, `SysHeight`). Hàm `ConvertTo-ScreenPixels` sẽ sử dụng tỷ lệ nội suy trực tiếp giữa kích thước ảnh Gemini nhìn thấy và không gian tọa độ `SetCursorPos` của Windows.
  - *Lý do*: Trên Windows 10/11, tỷ lệ Scale (125%, 150%) thường khiến `Screen.Bounds` trả về tọa độ logic nhỏ hơn số pixel của ảnh chụp thật, dẫn đến việc Gemini nhìn thấy ảnh 1920x1080 nhưng lệnh chuột lại tính theo 1536x864 làm chuột bị lệch 20-30%.
- **Quyết định 3: Chuỗi suy luận neo tọa độ (Thought-Coordinate Grounding)**:
  - *Phương án chọn*: Trong System Instruction, quy định cấu trúc `thought` bắt buộc phải kèm tên phần tử mục tiêu và khoảng ước lượng vị trí (ví dụ: `Target: Submit button, Center: [775, 885]`), và mảng `actions` phải lấy đúng giá trị `[775, 885]` đó.
  - *Lý do*: Ép Gemini thực hiện suy luận từng bước (Chain of Thought), triệt tiêu hoàn toàn hiện tượng hallucination khi sinh tọa độ JSON.

---

### 4. Technical Architecture & Data Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                        USER DESKTOP / CLIENT                           │
│  User Task (Any Language) ──> Web UI (index.html) / CLI (NguyeensCLI)  │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ HTTP / JSON Payload (UTF-8)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR & WORKER ENGINE                       │
│                                                                        │
│  ┌───────────────────────┐           ┌──────────────────────────────┐  │
│  │ Windows DPI Manager   │           │ Screen Capture Engine        │  │
│  │ Per-Monitor V2 Aware  ├──────────>│ Physical Frame (10 FPS JPEG) │  │
│  │ Metric Calibration    │           │ Ratio: RealScreen / Bitmap   │  │
│  └──────────┬────────────┘           └──────────────┬───────────────┘  │
│             │                                       │                  │
│             └───────────────────┬───────────────────┘                  │
│                                 ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Google Gemini Vision 3.5 Flash                                   │  │
│  │ - Multilingual Prompt Adapter (auto-detect user language)        │  │
│  │ - Visual Grounding CoT (Target Element -> Bounding Box -> Center)│  │
│  │ - Output: { thought: "... [Language]", actions: [{x, y}], ... }  │  │
│  └──────────────────────────────┬───────────────────────────────────┘  │
│                                 ▼                                      │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │ Exact Coordinate Mapper & Physical Windows Input                 │  │
│  │ - ConvertTo-ScreenPixels with dynamic DPI aspect ratio scaling   │  │
│  │ - Cubic Ease-Out Precision Mouse Movement to exact element center│  │
│  └──────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────┘
```

- **Các thành phần cần nâng cấp trong mã nguồn**:
  1. `worker.ps1`:
     - Nâng cấp `systemInstruction`: Gỡ bỏ ép buộc tiếng Việt, chuyển sang tự động phản hồi theo ngôn ngữ của người dùng; bổ sung quy tắc neo tọa độ thị giác (Visual Grounding CoT).
     - Nâng cấp `ConvertTo-ScreenPixels`: Tự động tính toán tỷ lệ co giãn giữa kích thước ảnh bitmap chụp được và không gian màn hình thực tế của Windows, đảm bảo chống lệch DPI 100%-200%.
  2. `NguyeensCLI.ps1` & `NguyeensAI.ps1`: Đảm bảo hiển thị UTF-8 trơn tru cho mọi ngôn ngữ khi xuất nhật ký.
  3. `packageFiles.ts` & `precompiledZip.ts`: Tái tạo gói ZIP mới nhất để người dùng tải về và giải nén là sử dụng được ngay.
