# Học Đàn Hát — Website khóa học thanh nhạc

Giao diện tĩnh host trên GitHub Pages, backend chạy trên Supabase.
Không cần cài đặt hay build — chỉ là HTML, CSS và JavaScript thuần.

## Cấu trúc

```
index.html               Trang chủ (header, hero, 3 section khóa học, giáo viên, footer)
assets/css/styles.css    Toàn bộ giao diện; đổi màu tại khối :root ở đầu file
assets/js/data.js        Danh sách bài hát của section "Học theo bài hát"
assets/js/main.js        Menu điện thoại, bộ lọc bài hát, thông báo "sắp ra mắt"
assets/img/              Logo, favicon; thêm ảnh giáo viên và ảnh bìa bài hát vào đây
.nojekyll                Báo GitHub Pages phục vụ file nguyên trạng, không qua Jekyll
```

## Xem thử trên máy

Mở thẳng file `index.html` bằng trình duyệt, hoặc chạy trong thư mục dự án:

```bash
python3 -m http.server 8080
# rồi mở http://localhost:8080
```

## Đưa lên GitHub Pages

1. Tạo một repository trống trên GitHub (ví dụ `web-music`).
2. Trong thư mục dự án:

   ```bash
   git init -b main
   git add .
   git commit -m "Trang chủ tĩnh Học Đàn Hát"
   git remote add origin https://github.com/<tài-khoản>/<tên-repo>.git
   git push -u origin main
   ```

3. Trên GitHub: **Settings → Pages → Source: Deploy from a branch**, chọn nhánh `main`,
   thư mục `/ (root)`, rồi bấm Save.
4. Từ đó mỗi lần push vào `main`, website tự cập nhật tại
   `https://<tài-khoản>.github.io/<tên-repo>/`.

Lưu ý: với tài khoản GitHub miễn phí, repository phải để public thì mới dùng được Pages.

## Backend

Backend chạy trên Supabase. Cách cài đặt, phân quyền và luồng thanh toán: xem `supabase/README.md`.

## Nội dung cần điền

Tìm các chỗ trong ngoặc vuông để thay bằng nội dung thật:

- `index.html`: `[GIÁ]`, `[SỐ BÀI]`, `[THỜI LƯỢNG]`, `[TÊN GIÁO VIÊN]`, `[GIỚI THIỆU NGẮN…]`,
  `[ẢNH GIÁO VIÊN]`, `[SỐ ĐIỆN THOẠI / ZALO]`, `[EMAIL]`, `[ĐỊA CHỈ]`
- `assets/js/data.js`: tên bài hát, ca sĩ, giá, ảnh bìa

## Chưa có trong giai đoạn này

Các nút Đăng nhập, Đăng ký, Đăng ký khóa học, Học bài này và Bài học thử hiện chỉ báo
"tính năng sắp ra mắt". Backend đã có schema và phân quyền, nhưng các trang đăng nhập, mua khóa
và xem video chưa được dựng. Webhook thanh toán QR chờ chọn nhà cung cấp.
