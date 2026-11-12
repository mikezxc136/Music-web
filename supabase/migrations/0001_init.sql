-- =====================================================================
-- Học Đàn Hát — schema khởi tạo (Supabase / Postgres)
-- Chạy MỘT LẦN trong Supabase Dashboard → SQL Editor, hoặc bằng psql.
--
-- Nguyên tắc bảo mật:
--   * Mọi bảng đều bật Row Level Security. Trình duyệt chỉ dùng anon key.
--   * Vai trò (student / teacher / admin) nằm ở profiles.role; người dùng
--     không tự đổi được vai trò của mình.
--   * Giá tiền luôn lấy từ bảng courses ở phía database (hàm create_order),
--     không bao giờ tin số tiền do trình duyệt gửi lên.
--   * Chỉ service role (webhook thanh toán) mới xác nhận được đơn hàng
--     và ghi danh học viên (hàm confirm_order_payment).
--   * Mã video nằm ở bảng riêng lesson_videos, chỉ người đã mua mới đọc được.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Kiểu dữ liệu ----------
create type public.user_role     as enum ('student', 'teacher', 'admin');
create type public.course_kind   as enum ('basic', 'advanced', 'song');   -- cơ bản / nâng cao / theo bài hát
create type public.course_status as enum ('draft', 'published', 'archived');
create type public.order_status  as enum ('pending', 'paid', 'cancelled', 'expired');

-- ---------- Tiện ích ----------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- =====================================================================
-- 1. TÀI KHOẢN
-- =====================================================================
create table public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  role        public.user_role not null default 'student',
  full_name   text not null default '',
  phone       text,
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Hồ sơ công khai của giáo viên (hiện trên trang chủ). Tách riêng để không lộ SĐT.
create table public.teacher_profiles (
  user_id       uuid primary key references public.profiles (id) on delete cascade,
  display_name  text not null,
  bio           text not null default '',
  photo_url     text,
  is_listed     boolean not null default false,
  sort_order    int not null default 0,
  updated_at    timestamptz not null default now()
);

create trigger teacher_profiles_updated_at before update on public.teacher_profiles
  for each row execute function public.set_updated_at();

-- Vai trò của người đang đăng nhập. SECURITY DEFINER để dùng được trong policy
-- mà không bị đệ quy RLS trên chính bảng profiles.
create or replace function public.current_role_name()
returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from public.profiles where id = auth.uid()), false)
$$;

create or replace function public.is_teacher()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((select role in ('teacher', 'admin') from public.profiles where id = auth.uid()), false)
$$;

-- Tự tạo profile khi có người đăng ký. Luôn là 'student', bất kể metadata gửi lên.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, full_name, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Chặn tự nâng quyền: chỉ admin (hoặc service role / SQL Editor) đổi được role.
create or replace function public.protect_profile_role()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.role is distinct from old.role
     and auth.uid() is not null
     and not public.is_admin() then
    raise exception 'Không có quyền thay đổi vai trò tài khoản';
  end if;
  return new;
end $$;

create trigger profiles_protect_role before update on public.profiles
  for each row execute function public.protect_profile_role();

-- =====================================================================
-- 2. KHÓA HỌC, BÀI HỌC, VIDEO
-- =====================================================================
create table public.courses (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  kind         public.course_kind not null,
  title        text not null,
  summary      text not null default '',
  description  text not null default '',
  price_vnd    integer check (price_vnd is null or price_vnd >= 0),   -- null = chưa đặt giá
  status       public.course_status not null default 'draft',
  teacher_id   uuid references public.profiles (id) on delete set null,
  cover_url    text,
  -- Riêng cho khóa theo bài hát:
  song_artist  text,
  song_genre   text check (song_genre is null or song_genre in ('nhac-tre', 'tru-tinh', 'nhac-trinh')),
  song_level   text check (song_level is null or song_level in ('Cơ bản', 'Trung bình', 'Nâng cao')),
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Không cho mở bán khi chưa có giá.
  constraint published_needs_price check (status <> 'published' or price_vnd is not null)
);

create index courses_kind_status_idx on public.courses (kind, status, sort_order);
create index courses_teacher_idx on public.courses (teacher_id);

create trigger courses_updated_at before update on public.courses
  for each row execute function public.set_updated_at();

create table public.lessons (
  id                uuid primary key default gen_random_uuid(),
  course_id         uuid not null references public.courses (id) on delete cascade,
  position          int not null check (position > 0),
  title             text not null,
  summary           text not null default '',
  duration_seconds  int check (duration_seconds is null or duration_seconds >= 0),
  is_free_preview   boolean not null default false,   -- bài "Học thử"
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (course_id, position)
);

create trigger lessons_updated_at before update on public.lessons
  for each row execute function public.set_updated_at();

-- Mã video ở nhà cung cấp (Bunny / Cloudflare Stream…). Bảng riêng, RLS chặt.
create table public.lesson_videos (
  lesson_id   uuid primary key references public.lessons (id) on delete cascade,
  provider    text not null,
  video_ref   text not null,
  updated_at  timestamptz not null default now()
);

create trigger lesson_videos_updated_at before update on public.lesson_videos
  for each row execute function public.set_updated_at();

-- =====================================================================
-- 3. ĐƠN HÀNG, GHI DANH, TIẾN ĐỘ
-- =====================================================================
create table public.orders (
  id            uuid primary key default gen_random_uuid(),
  code          text not null unique,          -- nội dung chuyển khoản, ví dụ HDH7K2M9QXA
  user_id       uuid not null references public.profiles (id) on delete restrict,
  course_id     uuid not null references public.courses (id) on delete restrict,
  amount_vnd    integer not null check (amount_vnd >= 0),
  status        public.order_status not null default 'pending',
  provider      text,
  provider_ref  text,                          -- mã giao dịch phía ngân hàng / cổng thanh toán
  paid_at       timestamptz,
  expires_at    timestamptz not null default now() + interval '24 hours',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index orders_user_idx on public.orders (user_id, created_at desc);
create index orders_status_idx on public.orders (status, created_at desc);
-- Mỗi giao dịch ngân hàng chỉ được dùng cho một đơn.
create unique index orders_provider_ref_uidx on public.orders (provider, provider_ref)
  where provider_ref is not null;
-- Mỗi người chỉ có một đơn đang chờ cho mỗi khóa.
create unique index orders_one_pending_uidx on public.orders (user_id, course_id)
  where status = 'pending';

create trigger orders_updated_at before update on public.orders
  for each row execute function public.set_updated_at();

create table public.enrollments (
  user_id     uuid not null references public.profiles (id) on delete cascade,
  course_id   uuid not null references public.courses (id) on delete restrict,
  order_id    uuid references public.orders (id) on delete set null,   -- null = admin cấp tay
  created_at  timestamptz not null default now(),
  primary key (user_id, course_id)
);

create index enrollments_course_idx on public.enrollments (course_id);

create table public.lesson_progress (
  user_id           uuid not null references public.profiles (id) on delete cascade,
  lesson_id         uuid not null references public.lessons (id) on delete cascade,
  position_seconds  int not null default 0 check (position_seconds >= 0),
  completed_at      timestamptz,
  updated_at        timestamptz not null default now(),
  primary key (user_id, lesson_id)
);

create trigger lesson_progress_updated_at before update on public.lesson_progress
  for each row execute function public.set_updated_at();

-- Nhật ký mọi lần webhook thanh toán gọi tới (để đối soát). Chỉ admin đọc.
create table public.payment_events (
  id           bigint generated always as identity primary key,
  provider     text not null,
  provider_ref text,
  order_code   text,
  amount_vnd   integer,
  outcome      text not null,
  payload      jsonb,
  created_at   timestamptz not null default now()
);

-- ---------- Hàm kiểm tra quyền học ----------
create or replace function public.is_enrolled(p_course_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.enrollments
    where user_id = auth.uid() and course_id = p_course_id
  )
$$;

create or replace function public.teaches_course(p_course_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.courses
    where id = p_course_id and teacher_id = auth.uid()
  )
$$;

-- Được xem video của bài học nếu: admin, giáo viên của khóa, đã ghi danh,
-- hoặc bài học thử của khóa đang mở bán.
create or replace function public.can_view_lesson(p_lesson_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.lessons l
    join public.courses c on c.id = l.course_id
    where l.id = p_lesson_id
      and (
        public.is_admin()
        or c.teacher_id = auth.uid()
        or (l.is_free_preview and c.status = 'published')
        or exists (
          select 1 from public.enrollments e
          where e.user_id = auth.uid() and e.course_id = c.id
        )
      )
  )
$$;

-- =====================================================================
-- 4. HÀM NGHIỆP VỤ
-- =====================================================================

-- Học viên tạo đơn. Giá lấy từ courses, không nhận từ trình duyệt.
-- Nếu đã có đơn đang chờ còn hạn cho khóa này thì trả lại đơn đó.
create or replace function public.create_order(p_course_id uuid)
returns public.orders
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_course public.courses;
  v_order  public.orders;
  v_code   text;
begin
  if v_uid is null then
    raise exception 'Bạn cần đăng nhập để đăng ký khóa học';
  end if;

  select * into v_course from public.courses where id = p_course_id;
  if not found or v_course.status <> 'published' or v_course.price_vnd is null then
    raise exception 'Khóa học không tồn tại hoặc chưa mở bán';
  end if;

  if exists (select 1 from public.enrollments where user_id = v_uid and course_id = p_course_id) then
    raise exception 'Bạn đã sở hữu khóa học này';
  end if;

  -- Đơn chờ đã hết hạn thì đóng lại.
  update public.orders set status = 'expired'
  where user_id = v_uid and course_id = p_course_id
    and status = 'pending' and expires_at <= now();

  select * into v_order from public.orders
  where user_id = v_uid and course_id = p_course_id and status = 'pending';
  if found then
    return v_order;
  end if;

  loop
    -- HDH + 8 ký tự, bỏ các ký tự dễ nhầm (0/O, 1/I/L).
    select 'HDH' || string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + (get_byte(b, i) % 31), 1), '')
      into v_code
    from (select gen_random_bytes(8) as b) r, generate_series(0, 7) as i;
    exit when not exists (select 1 from public.orders where code = v_code);
  end loop;

  insert into public.orders (code, user_id, course_id, amount_vnd)
  values (v_code, v_uid, p_course_id, v_course.price_vnd)
  returning * into v_order;

  return v_order;
end $$;

-- Webhook thanh toán gọi hàm này bằng SERVICE ROLE sau khi đã xác thực chữ ký.
-- An toàn khi gọi lặp: cùng một giao dịch gọi nhiều lần chỉ ghi nhận một lần.
create or replace function public.confirm_order_payment(
  p_order_code   text,
  p_amount_vnd   integer,
  p_provider     text,
  p_provider_ref text,
  p_payload      jsonb default null
)
returns text      -- 'paid' | 'already_paid' | 'not_found' | 'amount_mismatch' | 'not_payable'
language plpgsql security definer set search_path = public as $$
declare
  v_order   public.orders;
  v_outcome text;
begin
  select * into v_order from public.orders
  where code = upper(trim(p_order_code))
  for update;

  if not found then
    v_outcome := 'not_found';
  elsif v_order.status = 'paid' then
    v_outcome := 'already_paid';
  elsif v_order.status = 'cancelled' then
    v_outcome := 'not_payable';
  elsif p_amount_vnd is null or p_amount_vnd < v_order.amount_vnd then
    v_outcome := 'amount_mismatch';
  else
    -- Đơn 'pending' hoặc 'expired' mà tiền đã về đủ thì vẫn ghi nhận.
    update public.orders
    set status = 'paid', paid_at = now(), provider = p_provider, provider_ref = p_provider_ref
    where id = v_order.id;

    insert into public.enrollments (user_id, course_id, order_id)
    values (v_order.user_id, v_order.course_id, v_order.id)
    on conflict (user_id, course_id) do nothing;

    v_outcome := 'paid';
  end if;

  insert into public.payment_events (provider, provider_ref, order_code, amount_vnd, outcome, payload)
  values (p_provider, p_provider_ref, p_order_code, p_amount_vnd, v_outcome, p_payload);

  return v_outcome;
end $$;

-- Lưu tiến độ xem video. Chỉ lưu được cho bài mình có quyền xem.
create or replace function public.save_lesson_progress(
  p_lesson_id        uuid,
  p_position_seconds int,
  p_completed        boolean default false
)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'Bạn cần đăng nhập';
  end if;
  if not public.can_view_lesson(p_lesson_id) then
    raise exception 'Bạn chưa có quyền học bài này';
  end if;

  insert into public.lesson_progress (user_id, lesson_id, position_seconds, completed_at)
  values (auth.uid(), p_lesson_id, greatest(p_position_seconds, 0),
          case when p_completed then now() end)
  on conflict (user_id, lesson_id) do update
  set position_seconds = excluded.position_seconds,
      completed_at     = coalesce(public.lesson_progress.completed_at, excluded.completed_at);
end $$;

-- =====================================================================
-- 5. ROW LEVEL SECURITY
-- =====================================================================
alter table public.profiles         enable row level security;
alter table public.teacher_profiles enable row level security;
alter table public.courses          enable row level security;
alter table public.lessons          enable row level security;
alter table public.lesson_videos    enable row level security;
alter table public.orders           enable row level security;
alter table public.enrollments      enable row level security;
alter table public.lesson_progress  enable row level security;
alter table public.payment_events   enable row level security;

-- ---------- profiles ----------
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());
-- Không có policy insert/delete: profile do trigger tạo, xóa theo auth.users.

-- ---------- teacher_profiles ----------
create policy teacher_profiles_select on public.teacher_profiles for select to anon, authenticated
  using (is_listed or user_id = auth.uid() or public.is_admin());
create policy teacher_profiles_update_own on public.teacher_profiles for update to authenticated
  using (user_id = auth.uid() and public.is_teacher())
  with check (user_id = auth.uid() and public.is_teacher());
create policy teacher_profiles_admin on public.teacher_profiles for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- courses ----------
-- Ai cũng xem được khóa đang mở bán. Giáo viên xem khóa của mình. Admin xem tất cả.
create policy courses_select on public.courses for select to anon, authenticated
  using (status = 'published' or teacher_id = auth.uid() or public.is_admin());
-- Tạo khóa, đặt giá, mở bán: chỉ admin.
create policy courses_admin on public.courses for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- lessons ----------
-- Danh sách bài học (tên, mô tả) công khai với khóa đang mở bán.
create policy lessons_select on public.lessons for select to anon, authenticated
  using (
    public.is_admin()
    or public.teaches_course(course_id)
    or exists (select 1 from public.courses c where c.id = course_id and c.status = 'published')
  );
-- Giáo viên soạn bài cho khóa của mình; admin toàn quyền.
create policy lessons_write on public.lessons for all to authenticated
  using (public.is_admin() or public.teaches_course(course_id))
  with check (public.is_admin() or public.teaches_course(course_id));

-- ---------- lesson_videos ----------
create policy lesson_videos_select on public.lesson_videos for select to anon, authenticated
  using (public.can_view_lesson(lesson_id));
create policy lesson_videos_write on public.lesson_videos for all to authenticated
  using (
    public.is_admin()
    or exists (select 1 from public.lessons l where l.id = lesson_id and public.teaches_course(l.course_id))
  )
  with check (
    public.is_admin()
    or exists (select 1 from public.lessons l where l.id = lesson_id and public.teaches_course(l.course_id))
  );

-- ---------- orders ----------
-- Học viên chỉ đọc đơn của mình. Tạo đơn qua create_order(), xác nhận qua webhook.
create policy orders_select on public.orders for select to authenticated
  using (user_id = auth.uid() or public.is_admin());
create policy orders_admin_update on public.orders for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------- enrollments ----------
create policy enrollments_select on public.enrollments for select to authenticated
  using (user_id = auth.uid() or public.is_admin() or public.teaches_course(course_id));
-- Admin cấp hoặc thu hồi quyền học bằng tay.
create policy enrollments_admin_insert on public.enrollments for insert to authenticated
  with check (public.is_admin());
create policy enrollments_admin_delete on public.enrollments for delete to authenticated
  using (public.is_admin());

-- ---------- lesson_progress ----------
-- Chỉ đọc; ghi qua save_lesson_progress().
create policy lesson_progress_select on public.lesson_progress for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- ---------- payment_events ----------
create policy payment_events_admin on public.payment_events for select to authenticated
  using (public.is_admin());

-- =====================================================================
-- 6. QUYỀN GỌI HÀM
-- =====================================================================
revoke execute on function public.confirm_order_payment(text, integer, text, text, jsonb) from public, anon, authenticated;
grant  execute on function public.confirm_order_payment(text, integer, text, text, jsonb) to service_role;

revoke execute on function public.create_order(uuid) from public, anon;
grant  execute on function public.create_order(uuid) to authenticated;

revoke execute on function public.save_lesson_progress(uuid, int, boolean) from public, anon;
grant  execute on function public.save_lesson_progress(uuid, int, boolean) to authenticated;

revoke execute on function public.handle_new_user() from public, anon, authenticated;
revoke execute on function public.protect_profile_role() from public, anon, authenticated;
