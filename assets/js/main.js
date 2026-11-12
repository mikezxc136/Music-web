(function () {
  'use strict';

  /* ----- Menu trên điện thoại ----- */
  var toggle = document.querySelector('.nav-toggle');
  var nav = document.getElementById('main-nav');
  if (toggle && nav) {
    toggle.addEventListener('click', function () {
      var open = nav.classList.toggle('open');
      toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    nav.addEventListener('click', function (e) {
      if (e.target.closest('a')) {
        nav.classList.remove('open');
        toggle.setAttribute('aria-expanded', 'false');
      }
    });
  }

  /* ----- Danh sách bài hát + bộ lọc thể loại ----- */
  var songs = window.HDH_SONGS || [];
  var genres = window.HDH_GENRES || [];
  var grid = document.getElementById('song-grid');
  var chips = document.getElementById('song-chips');
  var current = 'all';

  function el(tag, cls, text) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null) n.textContent = text;
    return n;
  }

  function formatPrice(p) {
    return typeof p === 'number' ? p.toLocaleString('vi-VN') + ' đ' : '[GIÁ] đ';
  }

  function songCard(s) {
    var card = el('article', 'song-card');

    var cover = el('div', 'song-cover');
    if (s.cover) {
      var img = document.createElement('img');
      img.src = s.cover;
      img.alt = 'Ảnh bìa ' + s.title;
      img.loading = 'lazy';
      cover.appendChild(img);
    } else {
      cover.textContent = '[ẢNH BÌA BÀI HÁT]';
    }

    var info = el('div', 'song-info');
    info.appendChild(el('h3', 'song-title', s.title));
    info.appendChild(el('span', 'song-meta', s.artist + ' · ' + s.level));

    var foot = el('div', 'song-foot');
    foot.appendChild(el('span', 'song-price', formatPrice(s.price)));
    var buy = el('a', 'btn btn-accent btn-sm', 'Học bài này');
    buy.href = '#';
    buy.setAttribute('data-soon', 'Đăng ký mua bài hát');
    foot.appendChild(buy);

    card.appendChild(cover);
    card.appendChild(info);
    card.appendChild(foot);
    return card;
  }

  function renderSongs() {
    if (!grid) return;
    grid.textContent = '';
    var list = songs.filter(function (s) { return current === 'all' || s.genre === current; });
    if (!list.length) {
      grid.appendChild(el('p', 'songs-empty', 'Chưa có bài hát trong thể loại này.'));
      return;
    }
    list.forEach(function (s) { grid.appendChild(songCard(s)); });
  }

  function renderChips() {
    if (!chips) return;
    genres.forEach(function (g) {
      var b = el('button', 'chip', g.label);
      b.type = 'button';
      b.setAttribute('aria-pressed', g.id === current ? 'true' : 'false');
      b.addEventListener('click', function () {
        current = g.id;
        chips.querySelectorAll('.chip').forEach(function (c) { c.setAttribute('aria-pressed', 'false'); });
        b.setAttribute('aria-pressed', 'true');
        renderSongs();
      });
      chips.appendChild(b);
    });
  }

  renderChips();
  renderSongs();

  /* ----- Các nút chưa nối chức năng (đăng nhập, đăng ký, thanh toán) ----- */
  var toast = document.getElementById('toast');
  var toastTimer;
  document.addEventListener('click', function (e) {
    var a = e.target.closest('[data-soon]');
    if (!a || !toast) return;
    e.preventDefault();
    toast.textContent = a.getAttribute('data-soon') + ' — tính năng sắp ra mắt.';
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toast.classList.remove('show'); }, 2600);
  });

  /* ----- Năm ở footer ----- */
  var y = document.getElementById('year');
  if (y) y.textContent = new Date().getFullYear();
})();
