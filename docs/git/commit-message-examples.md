# Thông điệp commit: ví dụ tốt và ví dụ tệ

## Ví dụ tệ

```
fix
update code
sửa bug
WIP
fix lại lần cuối
```

Sau ba tháng, không ai — kể cả người viết — biết năm commit này làm gì. Lịch sử
mất hết giá trị, `git blame` chỉ ra một dòng chữ vô nghĩa, và `git bisect` chỉ
vào một commit khổng lồ chứa mười thay đổi không liên quan.

## Ví dụ tốt

```
Chặn hủy đơn đã thanh toán

Đơn ở trạng thái paid cần đối soát hoàn tiền với cổng thanh toán, mà
đội chưa làm phần đó. Cho hủy mà không hoàn tiền sẽ tạo ra đơn đã hủy
nhưng đã thu tiền, không ai xử lý được.

Đã cân nhắc: cho hủy rồi đánh dấu "chờ hoàn tiền". Bỏ vì trạng thái đó
không có ai theo dõi, sẽ tồn đọng âm thầm.
```

## Quy tắc của đội

- Dòng đầu ≤ 50 ký tự, viết ở thể mệnh lệnh, nói **cái gì** thay đổi.
- Dòng thứ hai để trống.
- Phần thân nói **vì sao**, và phương án nào đã bị loại. Phần diff đã nói
  **như thế nào** rồi, đừng chép lại.
- Một commit là một thay đổi có thể revert riêng. Nếu bạn phải viết "và" ở dòng
  đầu, đó là hai commit.

## Vì sao junior nên quan tâm

Người review đọc theo từng commit. `git blame` trả về từng commit. `git bisect`
chia đôi theo từng commit. Ba công cụ bạn sẽ dùng nhiều nhất đều lấy commit làm
đơn vị, nên chất lượng commit chính là chất lượng của ba công cụ đó.
