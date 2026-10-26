# Yêu cầu: bảng kê ký số cho ngân hàng

Bước 1 của `docs/design/system-design-method.md` cho bài toán ký số tài liệu
cho ngân hàng. Bản nháp của product owner và đội Đơn Hàng. Mọi con số ghi "giả
định" là giả định của đội, chưa phải số đo. Thiết kế trả lời ở
`docs/design/bank-signing-design-review.md`.

### Xuất phát

Các quyết định đã có, tài liệu này không mở lại: khóa ký hóa đơn nằm trong HSM,
chỉ Payments được gọi (ADR 0015); HSM đó là dịch vụ HSM của nhà cung cấp (ADR
0023); production chạy trên Kubernetes managed (ADR 0022).

Ngân hàng sở hữu một chuỗi cửa hàng trên Đơn Hàng, khách hàng của
`compliance-controls.md`. Ngân hàng muốn nhận mỗi tháng một bảng kê các khoản
thanh toán và hoàn tiền của các cửa hàng thuộc họ, do Payments ký.

Một chứng chỉ chỉ có hiệu lực giữa hai ngày. Thu hồi chứng chỉ là việc CA cấp
nó tuyên bố chứng chỉ hết hiệu lực trước ngày cuối, ví dụ vì khóa riêng có thể
đã lộ.

### Kịch bản

| Số | Tình huống | Phản hồi | Đo |
|---|---|---|---|
| KS-1 | Ngân hàng nhận một bảng kê | Ngân hàng tự kiểm chữ ký, chỉ bằng public key và chứng chỉ, không gọi Đơn Hàng | Mọi bảng kê kiểm được |
| KS-2 | Ngân hàng kiểm lại một bảng kê sau nhiều năm, chứng chỉ đã hết hạn | Vẫn kiểm được, và biết bảng kê được ký lúc nào | Kiểm được trong 10 năm (giả định) |
| KS-3 | Chứng chỉ bị thu hồi vì khóa có thể đã lộ | Bảng kê ký trước lúc thu hồi vẫn hợp lệ; bảng kê ký sau thì không | Phân biệt được mọi bảng kê |
| KS-4 | Ai đó muốn lấy khóa ra khỏi HSM | Không làm được | Khóa không bao giờ rời HSM |
| KS-5 | Payments xin ký một bảng kê | Lần xin ký được ghi lại, ngoài bảng của Payments | Mọi lần ký có một entry |

Kiểm soát của ngân hàng dùng lại bảng của `compliance-controls.md`, không chép
lại: KS-4 là TT-3; KS-5 là TT-2; tách nhiệm vụ giữa người duyệt thay đổi và
người làm là TT-1; rà soát ai có quyền ký và quyền quản trị khóa là TT-7.

### Ước lượng

- Bảng kê mỗi tháng: nhiều nhất vài trăm (giả định, một bảng kê cho mỗi cửa
  hàng của ngân hàng).
- Tải ký không đáng kể. Một bảng kê được chờ ký vài giờ (giả định) mà không
  phá driver nào, miễn trước hạn của ngân hàng: ngày làm việc thứ năm của
  tháng sau (giả định).
- Thứ khó nhất là thời gian, không phải tải: kiểm được sau 10 năm, sau khi
  chứng chỉ đã hết hạn hoặc bị thu hồi.

### Giả định và người xác nhận

| Giả định | Người xác nhận (vai trò) |
|---|---|
| Ngân hàng chỉ tin root do họ chỉ định; chứng chỉ do CA ngân hàng chỉ định cấp | Product owner, hỏi ngân hàng |
| Kiểm được trong 10 năm | Product owner, cùng kế toán |
| Hợp đồng không đòi HSM trên máy riêng | Product owner |
| Hạn của ngân hàng là ngày làm việc thứ năm của tháng sau | Product owner, hỏi ngân hàng |

### Driver xếp hạng

1. Kiểm được trong nhiều năm, kể cả sau khi chứng chỉ hết hạn (KS-1, KS-2).
2. Thiệt hại của một khóa lộ bị giới hạn theo thời gian (KS-3).
3. Không khóa nào nằm ngoài HSM (KS-4).
