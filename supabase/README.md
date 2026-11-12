# Backend — Supabase

Backend của Học Đàn Hát chạy hoàn toàn trên Supabase: đăng nhập (Auth), database Postgres
và phân quyền bằng Row Level Security. Website tĩnh trên GitHub Pages gọi thẳng Supabase
bằng **anon key**; không có server riêng.

## Cài đặt lần đầu

1. Mở Supabase Dashboard → **SQL Editor**.
2. Dán toàn bộ `migrations/0001_init.sql` → Run.
3. Dán toàn bộ `migrations/0002_seed_courses.sql` → Run.
4. Vào **Project Settings → API**, copy **anon public key** dán vào `assets/js/config.js`
   (mục `supabaseAnonKey`). Khóa này được phép công khai.
5. Vào **Authentication → URL Configuration**, đặt Site URL là địa chỉ website
   (ví dụ `https://mikezxc136.github.io/Music-web/`).

Không chạy lại `0001_init.sql` lần thứ hai (sẽ báo lỗi "already exists"). Thay đổi schema về sau
viết thành file mới `0003_...sql`, không sửa file cũ.

## Tạo tài khoản admin và giáo viên

Ai đăng ký cũng là **học viên**. Nâng quyền bằng SQL Editor:

```sql
update public.profiles set role = 'admin'
where id = (select id from auth.users where email = 'email-cua-ban@example.com');

update public.profiles set role = 'teacher'
where id = (select id from auth.users where email = 'email-giao-vien@example.com');
```

Sau khi có một admin, admin đổi vai trò người khác được từ giao diện quản trị (khi làm xong).

## Mở bán một khóa

```sql
update public.courses set price_vnd = 990000, status = 'published' where slug = 'khoa-co-ban';
```

(Số tiền trên chỉ là ví dụ cú pháp.) Khóa chưa có giá không mở bán được.

## Ai được làm gì

| | Khách | Học viên | Giáo viên | Admin |
|---|---|---|---|---|
| Xem khóa đang mở bán, danh sách bài học | ✔ | ✔ | ✔ | ✔ |
| Xem video bài học thử | ✔ | ✔ | ✔ | ✔ |
| Xem video khóa đã mua | | ✔ | | ✔ |
| Tạo đơn hàng (`create_order`) | | ✔ | ✔ | ✔ |
| Sửa bài học, video của khóa mình dạy | | | ✔ | ✔ |
| Xem danh sách học viên của khóa mình dạy | | | ✔ | ✔ |
| Tạo khóa, đặt giá, mở bán | | | | ✔ |
| Xem mọi đơn hàng, cấp/thu hồi quyền học, đổi vai trò | | | | ✔ |

Không ai (kể cả admin từ trình duyệt) tự đánh dấu "đã thanh toán" được. Việc đó chỉ xảy ra qua
hàm `confirm_order_payment`, chỉ service role gọi được.

## Luồng thanh toán

1. Học viên bấm mua → frontend gọi `create_order(course_id)` → nhận `code` (ví dụ `HDH7K2M9QXA`)
   và `amount_vnd`. Giá do database quyết định.
2. Frontend hiện mã QR chuyển khoản với nội dung = `code`, số tiền = `amount_vnd`.
3. Ngân hàng báo có tiền → nhà cung cấp (SePay / payOS) gọi webhook.
4. Webhook (Supabase Edge Function, **chưa viết** — chờ chọn nhà cung cấp) xác thực chữ ký rồi gọi
   `confirm_order_payment(code, số tiền, provider, mã giao dịch, payload)` bằng service role key.
5. Hàm đánh dấu đơn `paid` và ghi danh học viên. Gọi lặp không ghi nhận hai lần.
   Mọi lần gọi được lưu ở bảng `payment_events` để đối soát.

## Bí mật

- `anon key`: công khai, nằm trong `assets/js/config.js`.
- `service role key`, mật khẩu database, `DATABASE_URL`: chỉ nằm trong `.env` trên máy và trong
  Secrets của Edge Function. Không bao giờ đưa vào HTML/JS hay commit lên GitHub.
