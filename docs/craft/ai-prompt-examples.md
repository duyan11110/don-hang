# Dùng AI assistant: câu hỏi tốt và câu hỏi tệ

## Câu hỏi tệ

> Viết cho tôi chức năng hủy đơn hàng.

Không có phiên bản, không có ngữ cảnh, không có ràng buộc. Bạn sẽ nhận về một
đoạn code trông hợp lý, dùng thư viện bạn không có, theo quy ước không phải của
đội, và bạn không đủ thông tin để biết nó sai chỗ nào.

## Câu hỏi tốt

> Đây là `OrderService.Cancel` của tôi (dán code). Dự án dùng .NET 10 và
> PostgreSQL 17. Quy tắc nghiệp vụ: chỉ đơn ở trạng thái `new` mới hủy được;
> hủy đơn đã hủy phải trả về lỗi xung đột. Hiện tại đơn `shipped` cũng bị hủy.
> Chỉ ra chỗ sai, giải thích vì sao, và nói rõ điều gì trong .NET khiến nó xảy
> ra. Đừng viết lại cả phương thức.

## Ba việc nên giao

1. **Giải thích code lạ.** "Đoạn này làm gì, từng bước một?" — bạn kiểm tra được
   câu trả lời bằng cách chạy thử.
2. **Sinh test.** "Liệt kê các trường hợp biên cho phương thức này." Danh sách
   sai vẫn có ích; bạn chỉ cần đọc và loại bớt.
3. **Vịt cao su.** Viết vấn đề ra cho máy đọc, nhiều khi bạn tự thấy lỗi.

## Ba việc không nên giao

1. **Câu hỏi về giá trị mặc định, giới hạn, phiên bản.** Hỏi tài liệu chính thức.
   Trợ lý sinh ra văn bản nghe hợp lý, không phải sự thật đã kiểm chứng.
2. **Code bạn không đọc từng dòng.** Bạn ký tên vào commit, không phải nó.
3. **Dữ liệu thật của khách hàng.** Không dán vào bất kỳ công cụ ngoài nào.

## Một câu để nhớ

Trợ lý AI giống một đồng nghiệp rất tự tin, biết rất rộng, và thỉnh thoảng sai
hoàn toàn mà giọng vẫn y hệt lúc đúng. Bạn đối xử với nó như với bản nháp của
đồng nghiệp đó: đọc, kiểm tra, rồi mới dùng.
