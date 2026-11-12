-- =====================================================================
-- Dữ liệu ban đầu: hai khóa chính và khung bài học đang hiển thị trên trang chủ.
-- Cả hai ở trạng thái 'draft' và CHƯA CÓ GIÁ. Admin đặt giá rồi mới mở bán:
--
--   update public.courses set price_vnd = <giá>, status = 'published' where slug = 'khoa-co-ban';
--
-- Chạy sau 0001_init.sql. Chạy lại nhiều lần không tạo trùng.
-- =====================================================================

insert into public.courses (slug, kind, title, summary, sort_order) values
  ('khoa-co-ban', 'basic', 'Khóa cơ bản',
   'Cho người mới bắt đầu: hơi thở, khẩu hình, hát đúng cao độ và nhịp.', 1),
  ('khoa-nang-cao', 'advanced', 'Khóa nâng cao',
   'Mở rộng quãng giọng, nốt cao, rung giọng và xử lý sắc thái bài hát.', 2)
on conflict (slug) do nothing;

insert into public.lessons (course_id, position, title, summary, is_free_preview)
select c.id, v.position, v.title, v.summary, v.is_free_preview
from (values
  ('khoa-co-ban', 1, 'Hơi thở và tư thế hát',        'Lấy hơi bằng cơ hoành, giữ hơi, đẩy hơi đều',        true),
  ('khoa-co-ban', 2, 'Khẩu hình và phát âm',         'Mở khẩu hình, tròn vành rõ chữ tiếng Việt',           false),
  ('khoa-co-ban', 3, 'Cao độ và cảm âm',             'Nghe đúng, hát đúng nốt cùng đàn piano',              false),
  ('khoa-co-ban', 4, 'Nhịp phách cơ bản',            'Giữ nhịp, vào câu đúng phách',                        false),
  ('khoa-co-ban', 5, 'Hoàn thiện bài hát đầu tiên',  'Ghép kỹ thuật vào một bài hát trọn vẹn',              false),
  ('khoa-nang-cao', 1, 'Mở rộng quãng giọng',              'Luyện thanh lên cao, xuống trầm an toàn',         false),
  ('khoa-nang-cao', 2, 'Giọng ngực, giọng pha, giọng óc',  'Chuyển giọng mượt, không vỡ tiếng',               false),
  ('khoa-nang-cao', 3, 'Cộng minh và độ vang',             'Đặt vị trí âm thanh để giọng dày và sáng',        false),
  ('khoa-nang-cao', 4, 'Rung giọng và luyến láy',          'Vibrato tự nhiên, kỹ thuật trang trí câu hát',    false),
  ('khoa-nang-cao', 5, 'Xử lý sắc thái và trình diễn',     'To nhỏ, nhấn nhả, kể câu chuyện bằng giọng hát',  false)
) as v (slug, position, title, summary, is_free_preview)
join public.courses c on c.slug = v.slug
on conflict (course_id, position) do nothing;
