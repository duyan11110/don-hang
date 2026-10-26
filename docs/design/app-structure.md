# Thiết kế: cấu trúc thư mục của DonHang.App

Trạng thái: áp dụng từ stage-4. Áp dụng cho `DonHang.App/lib/`.

### Vì sao đổi

Tới stage-3, `lib/` chia theo loại file: `screens/`, `widgets/`, `offline/`,
`auth/`, cùng `models.dart`, `providers.dart` và `api_client.dart` dùng chung.
Code của việc đặt đơn nằm rải ở năm chỗ, mỗi chỗ chung với các phần khác; sửa
một phần phải mở nhiều thư mục, và không gì cho biết phần nào được dùng phần
nào. Từ stage-4 `lib/` chia theo feature: mỗi thư mục là một việc app làm cho
khách, với màn hình, provider, model và lời gọi API của việc đó.

### Thư mục

| Thư mục | Nội dung |
|---|---|
| `features/auth/` | Đăng nhập bằng Keycloak (`auth_controller.dart`, `keycloak_sign_in.dart`), đọc `sub` của token (`token_subject.dart`), phần bọc trình duyệt cho đăng nhập (`browser*.dart`), `login_screen.dart`, `auth_callback_screen.dart` |
| `features/catalog/` | Model `Product`, lời gọi API (`catalog_api.dart`, `catalogApiProvider`), danh sách sản phẩm có bản lưu trên máy (`catalog_providers.dart`: `productsProvider`, `productProvider`), màn hình danh sách và chi tiết, `ProductCatalog`, `ProductTile` |
| `features/ordering/` | Model đơn (`order.dart`: `OrderItemRequest`, `OrderResult`, `totalVnd`), lời gọi API (`orders_api.dart`: `ordersApiProvider`, `orderProvider`), hàng đợi offline (`order_queue.dart`, `queue_sync.dart`), màn hình đặt đơn, chi tiết đơn, đơn đang chờ |
| `shared/` | Phần truyền tải HTTP mọi feature dùng (`api_client.dart`: địa chỉ API, header token, `ApiProblem`, `ApiUnreachable`), lưu trên máy (`local_store.dart`) và phần bọc trình duyệt của nó (`browser*.dart`) |
| `design/` | Design system: token, theme, `Brand`, các component |
| `l10n/` | File ARB và code `gen-l10n` sinh ra |
| `gallery/`, `gallery_main.dart` | Gallery component, điểm vào riêng |
| `main.dart`, `router.dart` | Ghép các feature thành app |

Mỗi feature có một file công khai cùng tên (`features/catalog/catalog.dart`),
chỉ `export` những gì feature khác, `router.dart` hay `main.dart` dùng. Mọi
file khác trong thư mục là của riêng feature đó.

### Feature và module của backend

Hai feature mang tên module của `DonHang.Api`: Catalog (`DonHang.Catalog`, chỉ
được gọi qua `ICatalog`) và Ordering (`DonHang.Domain`,
`DonHang.Infrastructure`). Khi đội nói "Catalog" hay "Ordering", từ đó dẫn tới
code tương ứng ở cả hai phía. Auth không có module tương ứng: đăng nhập là
việc của Keycloak (ADR 0009), app chỉ giữ token.

### Quy tắc phụ thuộc

| Feature | Được dùng |
|---|---|
| Ordering | Catalog, Auth |
| Catalog | Auth |
| Auth | không feature nào |

- Một feature chỉ import file công khai của feature khác, và chỉ theo chiều
  trong bảng; không có hai feature nào dùng lẫn nhau.
- `shared/` và `design/` không import feature nào.
- `main.dart` và `router.dart` không thuộc feature nào: chúng import file công
  khai của các feature và ghép chúng lại, việc mà composition root làm cho
  `DonHang.Api`.

`test/architecture/feature_boundaries_test.dart` đọc mọi dòng import và export
dưới `lib/` và fail khi một dòng vi phạm các quy tắc trên, nêu file và dòng.

### Lời gọi API

`shared/api_client.dart` không biết model của feature nào. Mỗi feature có lớp
gọi API của nó (`CatalogApi`, `OrdersApi`) và provider của lớp đó; test thay
provider của feature (`catalogApiProvider`, `ordersApiProvider`) bằng bản giả.
Sản phẩm là dữ liệu công khai nên `CatalogApi` không gửi token; `OrdersApi` lấy
token từ `authProvider` ở mỗi request.

### Khi nào thêm feature

Thêm một feature khi có một việc mới cho khách, thay đổi vì lý do của riêng
nó. Một màn hình lẻ phục vụ một feature có sẵn thì vào feature đó. Một feature
mới phải có dòng trong bảng phụ thuộc, sửa cùng lúc với `allowed` trong
`feature_boundaries_test.dart`.
