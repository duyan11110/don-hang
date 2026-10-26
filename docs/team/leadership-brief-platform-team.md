# Đề nghị: lập đội platform trước đội sản phẩm thứ hai

Đề nghị ban lãnh đạo đồng ý lập một đội platform trước khi lập đội sản phẩm
thứ hai. Hiệu quả cho kinh doanh: cửa hàng mới mở được nhanh hơn, vì đội sản
phẩm không còn phải tự dựng và giữ cluster, deploy, giám sát; và các cửa hàng
giữ được mức dịch vụ đã cam kết (SLO trong `docs/design/slo.md`) trong lúc số
cửa hàng tăng. Mọi con số dưới đây là giả định của đội.

### Phương án

| Phương án | Chi phí | Điều phải bỏ |
|---|---|---|
| A. Không làm gì: giữ một đội bảy người | Không thêm người | Mở cửa hàng mới, production trên Kubernetes managed và giám sát production xếp hàng sau nhau trong một đội; cluster vẫn chỉ một người sửa được |
| B. Thêm người vào đội hiện có, lên mười bốn người | 7 người; khoảng 2 tới 3 sprint để người mới làm được việc | Số cặp người cần trao đổi từ 21 lên 91; mỗi người vẫn phải biết toàn bộ hệ thống, nên đội chậm lại khi lớn lên |
| C. Đề xuất: lập đội platform 3 tới 4 người trước, rồi đội sản phẩm thứ hai (Cửa hàng) 5 tới 7 người | 3 tới 4 người trước, 5 tới 7 người sau; đội hiện có dành một người trong 2 sprint để chuyển giao phần chung | Đội sản phẩm thứ hai bắt đầu muộn hơn so với lập nó ngay, khoảng thời gian đội platform cần để nhận phần chung (2 tới 3 sprint) |

Với C, khi đội Cửa hàng bắt đầu, đội đó deploy qua con đường đội platform đã
giữ sẵn, không phải học cluster từ đầu, nên làm ra việc cho cửa hàng sớm hơn.

### Điều chưa chắc

- Đội platform cần 3 tới 4 người. Con số đúng phụ thuộc phần việc chuyển
  production sang Kubernetes managed, chưa ước lượng xong.
- Thời gian đội platform nhận phần chung: 2 tới 3 sprint.

Tín hiệu làm đổi kế hoạch:

- Yêu cầu từ đội sản phẩm sang đội platform thường quá 2 ngày làm việc mới
  được trả lời: đội platform thiếu người.
- Số cửa hàng tăng chậm hơn giả định trong `multi-shop-requirements.md`: lùi
  việc lập đội Cửa hàng, đội platform giữ nguyên.
- Hai đội cùng phải sửa một phần hệ thống trong phần lớn thay đổi: ranh giới
  đội đặt sai, đội xem lại cách chia trước khi thêm người.

### Câu hỏi có thể gặp

- Nếu không đồng ý thì sao? Đội giữ phương án A. Các kết quả ở mục "Tiếp theo"
  của `roadmap.md` làm lần lượt, mỗi lần một, và đội báo lại thứ tự để ban lãnh
  đạo chọn kết quả nào đi trước.
- Sao không lập đội sản phẩm thứ hai trước, cho nhanh? Hai đội sản phẩm cùng tự
  giữ cluster và deploy thì mỗi đội làm lại cùng một việc, và lỗi ở phần chung
  không có ai chịu trách nhiệm rõ.
- Đội platform có thành chỗ mọi việc phải chờ không? Đội platform cung cấp
  dịch vụ để đội sản phẩm tự làm, không làm thay: đội sản phẩm tự deploy và tự
  trực cho service của mình.
- Khi nào thấy hiệu quả? Khi đội Cửa hàng ra thay đổi đầu tiên tới production
  mà không cần ai ngoài đội deploy giúp.

### Phụ lục

- Quyết định và các phương án đã cân: ADR 0025
  (`docs/adr/0025-to-chuc-doi-theo-luong-va-doi-platform.md`).
- Đội hôm nay, phần mỗi đội sở hữu, cách các đội làm việc với nhau:
  `team-structure.md`.
- Các kết quả đang chờ người làm: `roadmap.md`.
