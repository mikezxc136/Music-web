# Học Đàn Hát — hướng dẫn cho Claude

Website bán khóa học thanh nhạc của thương hiệu **Học Đàn Hát — Piano & Thanh Nhạc**.
Đây là dự án thật, mục tiêu là vận hành được ở mức production. Chủ dự án làm việc bằng tiếng Việt.

## Trạng thái hiện tại

**Giai đoạn 1–2.** Trang chủ tĩnh (`index.html`) đã xong. Backend Supabase đã có schema,
phân quyền và lớp gọi API (`assets/js/api.js`), nhưng **chưa trang nào dùng tới**: chưa có trang
đăng nhập, đăng ký, mua khóa hay xem video. Webhook thanh toán chưa viết.

- Repo: https://github.com/mikezxc136/Music-web (nhánh `main`)
- Hosting: GitHub Pages, kiểu "Deploy from a branch" (`main`, thư mục gốc). Push vào `main` là lên web.
- Không có bước build, không có `package.json`. HTML, CSS, JavaScript thuần.
- Backend: **Supabase** (Auth + Postgres + Row Level Security). Không có server riêng; trình duyệt
  gọi thẳng Supabase bằng anon key. Chi tiết: `supabase/README.md`.

## Sản phẩm

- Ba nhóm khóa học: **Khóa cơ bản**, **Khóa nâng cao**, **Học theo bài hát** (mua lẻ từng bài).
- Hình thức học: video quay sẵn, mua một lần xem trọn đời.
- Ba loại tài khoản: **học viên**, **giáo viên**, **admin**.
- Thanh toán: chuyển khoản QR, tự động xác nhận (SePay hoặc payOS — chưa chọn).

## Cấu trúc

```
index.html               Trang chủ: header, hero, 3 lộ trình, 3 section khóa học, 3 bước, giáo viên, footer
assets/css/styles.css    Toàn bộ CSS. Biến màu và font nằm trong :root ở đầu file
assets/js/data.js        Dữ liệu bài hát (window.HDH_SONGS, window.HDH_GENRES)
assets/js/main.js        Menu điện thoại, render + lọc bài hát, thông báo "sắp ra mắt"
assets/js/config.js      Cấu hình công khai: supabaseUrl, supabaseAnonKey (được commit)
assets/js/api.js         Lớp gọi backend: window.HDH.api (đăng nhập, khóa học, đơn hàng, tiến độ)
supabase/migrations/     SQL schema + phân quyền. File đã chạy thì không sửa, thêm file mới
supabase/README.md       Cách cài backend, bảng phân quyền, luồng thanh toán
assets/img/              Logo, favicon. Ảnh bài hát đặt ở assets/img/songs/
.env.example             Mẫu biến môi trường (được commit)
.env                     Giá trị thật (KHÔNG commit, đã nằm trong .gitignore)
.nojekyll                Bắt buộc giữ, để GitHub Pages phục vụ file nguyên trạng
```

## Chạy và kiểm tra

```bash
python3 -m http.server 8080    # rồi mở http://localhost:8080
```

Không có test tự động. Trước khi báo xong một thay đổi giao diện, phải mở trang và kiểm tra ở
hai bề rộng: **1440px** (máy tính) và **390px** (điện thoại). Kiểm tra: không tràn ngang,
menu điện thoại mở được, bộ lọc bài hát chạy, console không có lỗi.

## Backend (Supabase)

- Bảng: `profiles` (vai trò), `teacher_profiles`, `courses`, `lessons`, `lesson_videos`, `orders`,
  `enrollments`, `lesson_progress`, `payment_events`. Tất cả bật RLS.
- Mọi lời gọi backend từ giao diện đi qua `window.HDH.api` trong `assets/js/api.js`. Không gọi
  `supabase.from(...)` rải rác trong các trang; cần hàm mới thì thêm vào `api.js`.
- Trang nào dùng backend thì nạp theo thứ tự: supabase-js (CDN) → `config.js` → `api.js`.
- Tạo đơn chỉ qua RPC `create_order` (giá do database quyết định). Xác nhận thanh toán chỉ qua
  `confirm_order_payment`, chỉ service role gọi được. Lưu tiến độ qua `save_lesson_progress`.
- Đổi schema: viết file mới `supabase/migrations/000N_ten.sql`, kèm policy RLS cho bảng mới.
  Bảng mới không có RLS là lỗi nghiêm trọng. Chủ dự án tự chạy SQL trong Supabase SQL Editor.
- Phiên Claude không kết nối được tới database (mạng bị chặn), nên không tự chạy migration được.
  Có thể thử SQL trên Postgres cục bộ với schema `auth` giả lập trước khi giao.

## Thiết kế — đã được chủ dự án duyệt, giữ nguyên

Tone vàng nhạt / kem / ngà trắng theo logo vàng. Không đổi bảng màu, font hay bố cục trang chủ
nếu không được yêu cầu.

| Vai trò | Biến CSS | Giá trị |
|---|---|---|
| Nền chính (ngà) | `--ivory` | `#FFFBF0` |
| Nền phụ (kem) | `--cream` | `#FBF1D3` |
| Vàng nhấn (theo logo) | `--accent` | `#F2B84B` |
| Chữ chính, nút đậm (nâu) | `--brown` | `#4A2A10` |
| Chữ phụ | `--text-2`, `--text-3` | `#6B4A1E`, `#7A5A3A` |
| Viền | `--line`, `--line-strong` | `#F0E2BC`, `#EBD493` |

- Font: **Be Vietnam Pro** (Google Fonts), độ đậm 400–800.
- Bo góc: thẻ 22px (`--radius`), khối lớn 28px, nút và nhãn bo tròn hẳn (999px).
- Bề rộng nội dung tối đa 1200px (`.container`).
- Icon: SVG nét vẽ inline. Không dùng emoji, không dùng thư viện icon.

## Quy ước code

- **Luôn dùng biến màu** trong `:root`, không viết mã hex mới rải rác trong CSS.
- **Tái dùng class có sẵn** trước khi tạo mới: `.btn` (`.btn-dark`, `.btn-accent`, `.btn-outline`,
  `.btn-sm`, `.btn-block`), `.pill`, `.container`, `.section`, `.band-cream`, `.card-row`, `.h2`, `.lead`.
- CSS theo từng khối có chú thích tiêu đề; thêm khối mới ở cuối, trước phần `@media`.
- Responsive bằng flex-wrap và grid. Hai điểm ngắt: 900px và 640px.
- JavaScript thuần trong IIFE, không framework, không thư viện ngoài. Tạo phần tử bằng
  `createElement` + `textContent`, **không dùng `innerHTML`** với dữ liệu.
- Trang mới: copy phần `<head>`, header và footer từ `index.html` để giữ đồng nhất. Khi sửa header
  hoặc footer thì sửa ở mọi trang.
- Đường dẫn file luôn **tương đối** (`assets/...`, không có `/` ở đầu), vì trang chạy dưới
  `mikezxc136.github.io/Music-web/`.
- Toàn bộ nội dung hiển thị viết bằng **tiếng Việt có dấu**, `lang="vi"`. Tên file và id không dấu,
  viết thường, nối bằng gạch ngang (`khoa-co-ban`).
- Tiền: số nguyên VND, hiển thị bằng `toLocaleString('vi-VN') + ' đ'`.

## Khả năng truy cập — bắt buộc

- Dùng đúng thẻ: `<a href>` để điều hướng, `<button>` cho hành động, `<label>` cho ô nhập.
- Nút chỉ có icon phải có `aria-label`. SVG trang trí có `aria-hidden="true"`.
- Chữ đạt tương phản 4.5:1. Vùng bấm tối thiểu 44px.
- Giữ kiểu viền focus (`:focus-visible`) và link "Bỏ qua, tới nội dung chính".

## Nội dung và placeholder

Chỗ nào chưa có thông tin thật thì để trong ngoặc vuông viết hoa: `[GIÁ]`, `[SỐ BÀI]`,
`[TÊN BÀI HÁT]`, `[TÊN GIÁO VIÊN]`, `[SỐ ĐIỆN THOẠI / ZALO]`…

**Không bao giờ bịa** giá, số học viên, đánh giá, tên giáo viên, tên bài hát hay thông tin liên hệ.
Thiếu thì giữ placeholder và hỏi chủ dự án.

Nút chưa có chức năng thật (đăng nhập, đăng ký, mua khóa, học thử) mang thuộc tính
`data-soon="Tên tính năng"` để hiện thông báo "sắp ra mắt". Khi làm xong tính năng thì gỡ
thuộc tính này và trỏ `href` tới trang thật.

## Bảo mật — không được vi phạm

- **Không commit `.env`**, không in giá trị trong `.env` ra log, không dán vào câu trả lời.
- **Không đưa bí mật vào HTML/JS phía trình duyệt.** Mọi thứ trong repo này và trên GitHub Pages
  đều công khai. Mật khẩu database, service role key, khóa API thanh toán chỉ được dùng ở server.
- Kiểm tra quyền (học viên / giáo viên / admin) phải thực hiện ở server hoặc bằng luật phân quyền
  của database. Ẩn nút ở giao diện không phải là phân quyền.
- Trạng thái "đã thanh toán" chỉ được ghi từ webhook đã xác thực chữ ký, không bao giờ từ trình duyệt.
- Video trả phí phải phát qua link có ký và hết hạn, không để link file công khai.

## Git

- Commit bằng tiếng Việt, ngắn gọn, nói rõ thay đổi gì. Ví dụ: `Thêm trang đăng nhập`.
- Push vào `main` là lên web ngay, nên chỉ commit và push khi chủ dự án yêu cầu.
- Trước khi commit, chạy `git status` để chắc chắn `.env` không nằm trong danh sách.

## Lộ trình

1. **Web tĩnh (đang làm):** trang chủ ✔. Tiếp theo: trang chi tiết từng khóa, trang đăng nhập /
   đăng ký, trang xem video, bảng điều khiển học viên, giáo viên, admin (giao diện trước).
   Bổ sung hình ảnh thật và chỉnh lại header, footer theo yêu cầu chủ dự án.
2. **Backend:** schema + phân quyền ✔ (cần chủ dự án chạy SQL và điền anon key). Tiếp theo: nối
   các trang đăng nhập / đăng ký / tài khoản vào `HDH.api`, lấy khóa học và bài hát từ database
   thay cho `data.js`.
3. **Thanh toán QR:** tạo mã QR theo đơn, webhook xác nhận, tự mở khóa học.
4. **Video:** nơi lưu có chống tải lậu, ghi nhớ tiến độ học.
5. **Production:** tên miền riêng, hosting chính thức, sao lưu, theo dõi lỗi.

## Việc còn mở — hỏi chủ dự án, đừng tự quyết

- Nhà cung cấp QR: SePay hay payOS.
- Nơi lưu video: Bunny Stream, Cloudflare Stream hay dịch vụ khác.
- Hosting production và tên miền.
- Khi nào chuyển sang framework có build. Hiện giữ HTML thuần cho tới khi backend được chốt;
  không tự ý thêm framework, bundler hay thư viện.

## Cách làm việc với chủ dự án

- Trả lời bằng tiếng Việt, ngắn gọn, nói kết quả trước.
- Giao diện mới: đưa bản xem trước để duyệt rồi mới làm rộng ra.
- Thay đổi khó đảo ngược (cấu trúc database, đổi công nghệ, xóa dữ liệu, thanh toán) phải hỏi trước.
