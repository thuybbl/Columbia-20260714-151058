code_base:                   v1.2
instructions:                v1.3
packageName:                 com.binarybridge.ai.columbia
appName:                     Columbia
Review Design Before Coding: Fail


Về sản phẩm lần này:

- Core logic: sử dụng API gọi model sinh video AI, có trang cấu hình, tính năng crop ảnh đầu vào. Logic credit ở local để gọi API
- Kỳ vọng: Điểm quan trọng của app này là màn generation có nút toggle để đổi mode text - image. Khi dùng mode image to video thì UI có khả năng click để import ảnh. Màn hình này có thể cấu hình thêm resolu, ratio, duration (2-15s). Mỗi khi import ảnh, hiển nhiên sẽ dùng dialog của google để xem gallery của máy, khi click chọn thì sẽ mở một màn crop ảnh. Ở màn Home, sẽ có 3 entry giúp vào màn Generation: một thanh input lớn, nút FAB, và 1 thanh 2 gồm 2 nút là 2 mode text/image to video (design này có thể hơi lặp quá nhiều nhưng hãy cứ tuân theo), chú ý rằng riêng với thanh 2 nút này, nếu click vào image to video thì sẽ chuyển sang 1 màn phụ chỉ để người dùng bấm import ảnh, sau đó vẫn sẽ vào Generation nhưng đặt ảnh đã import vào (có ý đồ riêng). Chi tiết và các tính năng khác sẽ được phổ biến khi thực hiện nhiệm vụ.

