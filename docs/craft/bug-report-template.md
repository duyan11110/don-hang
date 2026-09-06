# Mẫu báo lỗi

## Mẫu

```
Tiêu đề: <một lỗi, nói rõ triệu chứng>
Các bước tái hiện:
  1. ...
  2. ...
Kết quả mong đợi: ...
Kết quả thực tế: ...
Môi trường: <phiên bản, môi trường, tài khoản, dữ liệu>
Bằng chứng: <log, ảnh chụp, id bản ghi>
Mức ảnh hưởng: <ai bị ảnh hưởng, bao nhiêu người, có cách nào đi vòng không>
Nghi ngờ nguyên nhân: <nếu có — ghi rõ đây là phỏng đoán>
```

## Ví dụ điền đầy đủ

> **Tiêu đề:** Tổng tiền đơn nhiều dòng thiếu đúng dòng cuối cùng
>
> **Các bước tái hiện:**
> 1. Mở màn hình chi tiết đơn số 1 (đơn có hai dòng: bàn phím và hai con chuột).
> 2. Nhìn dòng "Tổng cộng".
>
> **Kết quả mong đợi:** 2.150.000 đồng.
>
> **Kết quả thực tế:** 1.250.000 đồng — đúng bằng giá dòng đầu tiên.
>
> **Môi trường:** môi trường thử nghiệm, dữ liệu mẫu của lab.
>
> **Bằng chứng:** đơn 1 và đơn 3 đều sai; đơn 2 chỉ có một dòng nên hiện 0.
>
> **Mức ảnh hưởng:** mọi đơn nhiều dòng, tức phần lớn đơn. Không có cách đi
> vòng. Khách nhìn thấy số sai trên màn hình xác nhận.
>
> **Nghi ngờ nguyên nhân (phỏng đoán):** vòng lặp tính tổng dừng sớm một bước.

## Ba quy tắc

1. **Một lỗi một báo cáo.** Báo cáo gộp ba vấn đề thường được sửa không vấn đề nào.
2. **Tái hiện nhỏ nhất.** Đơn 2 chỉ có một dòng và hiện 0 — chi tiết đó thu hẹp
   phạm vi hơn cả trang mô tả.
3. **Phân biệt mức ảnh hưởng và độ ưu tiên.** Mức ảnh hưởng do bạn quan sát; độ
   ưu tiên do người quản lý sản phẩm quyết định. Đừng tự đặt cả hai.
