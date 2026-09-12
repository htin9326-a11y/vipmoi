# Aujunpeak VN — sửa lỗi hiển thị giao diện

## Đã xử lý

- Chừa riêng vùng 52pt cho navigation rail trên màn hình iPhone để menu không che chữ, icon hoặc công tắc.
- Khóa chiều rộng các màn Home, Function, Info và màn nhập key theo vùng hiển thị thực tế.
- Ép các lớp overlay trong Function/Info co theo màn hình thay vì lấy chiều rộng lý tưởng của nội dung.
- Cho tên chức năng, mô tả, bundle ID, Device ID và thông báo lỗi tự xuống dòng hoặc rút gọn đúng cách.
- Giữ các thẻ game và trạng thái không bị tràn ngang khi dùng tên game hoặc dữ liệu server dài.
- Cải thiện bố cục ở kích thước chữ lớn và màn hình iPhone nhỏ.

## Ghi chú kiểm tra

Mã nguồn đã được kiểm tra lại các thay đổi layout bằng diff và rà soát cú pháp SwiftUI. Việc build IPA cần thực hiện trên macOS/Xcode vì môi trường đóng gói hiện tại không có Xcode/iOS SDK.