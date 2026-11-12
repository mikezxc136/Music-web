/* Dữ liệu bài hát cho section "Học theo bài hát".
   Sửa trực tiếp tại đây; sau này sẽ thay bằng dữ liệu từ database.

   - title:  tên bài hát
   - artist: ca sĩ thể hiện
   - genre:  "nhac-tre" | "tru-tinh" | "nhac-trinh"
   - level:  "Cơ bản" | "Trung bình" | "Nâng cao"
   - price:  giá bằng số (VND), ví dụ 199000. Để null nếu chưa có giá.
   - cover:  đường dẫn ảnh bìa, ví dụ "assets/img/songs/ten-bai.jpg". Để "" nếu chưa có.
*/
window.HDH_GENRES = [
  { id: 'all', label: 'Tất cả' },
  { id: 'nhac-tre', label: 'Nhạc trẻ' },
  { id: 'tru-tinh', label: 'Trữ tình' },
  { id: 'nhac-trinh', label: 'Nhạc Trịnh' }
];

window.HDH_SONGS = [
  { title: '[TÊN BÀI HÁT 1]', artist: '[CA SĨ]', genre: 'nhac-tre', level: 'Cơ bản', price: null, cover: '' },
  { title: '[TÊN BÀI HÁT 2]', artist: '[CA SĨ]', genre: 'tru-tinh', level: 'Trung bình', price: null, cover: '' },
  { title: '[TÊN BÀI HÁT 3]', artist: '[CA SĨ]', genre: 'nhac-trinh', level: 'Nâng cao', price: null, cover: '' },
  { title: '[TÊN BÀI HÁT 4]', artist: '[CA SĨ]', genre: 'nhac-tre', level: 'Cơ bản', price: null, cover: '' }
];
