/* Lớp gọi backend (Supabase) cho toàn bộ website.
   Cần nạp trước file này, theo đúng thứ tự:
     <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
     <script src="assets/js/config.js"></script>
     <script src="assets/js/api.js"></script>

   Chỉ dùng anon key (công khai). Mọi kiểm tra quyền nằm ở Row Level Security
   trong database — xem supabase/migrations/0001_init.sql. */
(function () {
  'use strict';

  var cfg = window.HDH_CONFIG || {};
  var client = null;

  function isConfigured() {
    return Boolean(cfg.supabaseUrl && cfg.supabaseAnonKey && window.supabase);
  }

  function db() {
    if (!isConfigured()) {
      throw new Error('Chưa cấu hình backend: điền supabaseUrl và supabaseAnonKey trong assets/js/config.js');
    }
    if (!client) client = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
    return client;
  }

  // Trả về data hoặc ném lỗi có thông điệp tiếng Việt từ database.
  async function run(query) {
    var res = await query;
    if (res.error) throw new Error(res.error.message || 'Có lỗi xảy ra, vui lòng thử lại');
    return res.data;
  }

  var api = {
    isConfigured: isConfigured,

    /* ----- Tài khoản ----- */
    signUp: function (email, password, fullName, phone) {
      return run(db().auth.signUp({
        email: email,
        password: password,
        options: { data: { full_name: fullName || '', phone: phone || '' } }
      }));
    },
    signIn: function (email, password) {
      return run(db().auth.signInWithPassword({ email: email, password: password }));
    },
    signOut: async function () {
      var res = await db().auth.signOut();
      if (res.error) throw new Error(res.error.message);
    },
    getUser: async function () {
      var res = await db().auth.getUser();
      return res.data ? res.data.user : null;
    },
    // Hồ sơ + vai trò ('student' | 'teacher' | 'admin') của người đang đăng nhập.
    getMyProfile: async function () {
      var user = await api.getUser();
      if (!user) return null;
      return run(db().from('profiles').select('*').eq('id', user.id).single());
    },
    onAuthChange: function (callback) {
      return db().auth.onAuthStateChange(function (_event, session) {
        callback(session ? session.user : null);
      });
    },

    /* ----- Khóa học ----- */
    // kind: 'basic' | 'advanced' | 'song' (bỏ trống = tất cả khóa đang mở bán)
    listCourses: function (kind) {
      var q = db().from('courses')
        .select('id, slug, kind, title, summary, price_vnd, cover_url, song_artist, song_genre, song_level')
        .eq('status', 'published')
        .order('sort_order');
      if (kind) q = q.eq('kind', kind);
      return run(q);
    },
    getCourse: function (slug) {
      return run(db().from('courses').select('*').eq('slug', slug).single());
    },
    listLessons: function (courseId) {
      return run(db().from('lessons')
        .select('id, position, title, summary, duration_seconds, is_free_preview')
        .eq('course_id', courseId)
        .order('position'));
    },
    // Chỉ trả về dữ liệu nếu đã mua khóa, hoặc là bài học thử.
    getLessonVideo: function (lessonId) {
      return run(db().from('lesson_videos').select('provider, video_ref').eq('lesson_id', lessonId).maybeSingle());
    },
    listTeachers: function () {
      return run(db().from('teacher_profiles')
        .select('user_id, display_name, bio, photo_url')
        .eq('is_listed', true)
        .order('sort_order'));
    },

    /* ----- Mua khóa & học ----- */
    // Trả về đơn hàng: dùng order.code làm nội dung chuyển khoản, order.amount_vnd làm số tiền.
    createOrder: function (courseId) {
      return run(db().rpc('create_order', { p_course_id: courseId }));
    },
    getOrder: function (orderId) {
      return run(db().from('orders').select('id, code, amount_vnd, status, paid_at, expires_at, course_id').eq('id', orderId).single());
    },
    listMyOrders: function () {
      return run(db().from('orders')
        .select('id, code, amount_vnd, status, paid_at, created_at, courses(title, slug)')
        .order('created_at', { ascending: false }));
    },
    listMyCourses: async function () {
      var user = await api.getUser();
      if (!user) return [];
      return run(db().from('enrollments')
        .select('created_at, courses(id, slug, kind, title, summary, cover_url)')
        .eq('user_id', user.id)
        .order('created_at', { ascending: false }));
    },
    saveProgress: function (lessonId, positionSeconds, completed) {
      return run(db().rpc('save_lesson_progress', {
        p_lesson_id: lessonId,
        p_position_seconds: Math.floor(positionSeconds || 0),
        p_completed: Boolean(completed)
      }));
    },
    listMyProgress: function () {
      return run(db().from('lesson_progress').select('lesson_id, position_seconds, completed_at'));
    }
  };

  window.HDH = window.HDH || {};
  window.HDH.api = api;
})();
