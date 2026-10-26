# Feature flag trong Đơn Hàng

Trạng thái: quy ước từ stage-4. Feature flag là một cấu hình code đọc trong
lúc chạy để chọn giữa hai nhánh, nên một tính năng được deploy ở trạng thái
tắt và bật sau, không cần deploy lại. Ở stage-4 API Đơn Hàng chưa có flag
nào; cách tính flag theo phần trăm khách nằm trong
`samples/DonHang.Samples/Samples/Release/FeatureFlags.cs`. Tài liệu này là quy
ước cho flag đầu tiên và các flag sau.

### Hai loại flag

- Flag phát hành: giấu một tính năng chưa xong hoặc chưa tới ngày ra mắt.
  Nó chỉ sống tới khi tính năng bật cho mọi khách, rồi bị gỡ khỏi code cùng
  nhánh cũ.
- Kill switch: tắt một tính năng tốn tài nguyên khi hệ thống quá tải, để phần
  chính (đặt đơn, xem đơn) vẫn chạy. Đây là một cách giảm chức năng có kiểm
  soát. Kill switch ở lại lâu dài, và được thử tắt bật như mọi đường code
  khác.

Một flag chỉ thuộc một loại. Flag phát hành không được giữ lại làm kill
switch "cho chắc": hai việc cần hai tên và hai người phụ trách.

### Người phụ trách và ngày gỡ

Mỗi flag phát hành có, ngay khi được thêm:

- một người phụ trách, ghi theo vai trò;
- một ngày gỡ, thường là một sprint sau ngày dự định bật cho mọi khách.

Mỗi flag làm số đường code phải chạy đúng tăng gấp đôi: code có hai flag có
bốn tổ hợp. Test của tính năng chạy cả nhánh bật lẫn nhánh tắt.

Flag quá ngày gỡ mà còn trong code được ghi vào sổ nợ kỹ thuật
(`docs/team/tech-debt-register.md`) như một món nợ, với người phụ trách của
flag là người theo dõi.

### Bảng flag đang có

| Tên | Loại | Người phụ trách | Ngày gỡ | Trạng thái |
|---|---|---|---|---|
| (chưa có flag nào ở stage-4) | | | | |

Thêm, bật hay gỡ một flag thì sửa bảng này trong cùng pull request.

### Bật theo phần trăm khách

Một flag phát hành được bật dần theo phần trăm khách, không theo phần trăm
request. Bật theo request thì cùng một khách lúc thấy tính năng, lúc không
trong cùng một phiên.

Mỗi khách được gán một số từ 0 tới 99 tính từ tên flag và id khách bằng một
hàm băm cố định, không bằng `GetHashCode` (kết quả của nó đổi giữa các lần
chạy). Khách bật khi số đó nhỏ hơn phần trăm của flag. Vì thế:

- cùng khách luôn nhận cùng kết quả;
- tăng phần trăm chỉ thêm khách: ai đã bật ở 10% vẫn bật ở 50%;
- 0% tắt cho mọi khách, 100% bật cho mọi khách.

Tên flag nằm trong phép tính, nên hai flag cùng 10% không rơi vào cùng một
nhóm khách.

### Flag không thay expand và contract

Code nằm sau một flag đang tắt vẫn được deploy và vẫn chạy trên schema hiện
tại của database. Một thay đổi schema cho tính năng mới vẫn đi theo các bước
expand và contract: thêm cột hay bảng trước, code cả hai nhánh chạy được với
schema đó, chỉ bỏ phần cũ sau khi flag đã gỡ. Tắt flag không đưa schema về
như cũ.

### Flag và lịch phát hành

Code của tính năng có thể lên production bất kỳ ngày nào qua canary (ADR
0019), sau một flag đang tắt. Ngày bật flag cho khách là việc của lịch phát
hành (`docs/team/release-calendar.md`), không phải của lần deploy.
