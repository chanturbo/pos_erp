# Restaurant Testing Checklist

ใช้เอกสารนี้แยกจาก `TESTING_CHECKLIST.md` สำหรับตรวจรับโมดูลร้านอาหารก่อนปล่อยใช้งานจริง

## สาขาและข้อมูลตั้งต้น
- [ ] สาขาที่จะใช้งานถูกตั้ง `business_mode` เป็น `RESTAURANT` หรือ `HYBRID`
- [ ] มี zone และโต๊ะครบตามผังร้าน
- [ ] สินค้าที่ใช้ในร้านอาหารถูกตั้ง `service_mode`, `prep_station`, `requires_preparation`
- [ ] สินค้าที่ขายหน้าร้านมี stock เพียงพอใน warehouse ของสาขา
- [ ] ตั้งค่า `default service charge` และ `manager PIN` ตามนโยบายร้านแล้ว

## โต๊ะและ Session
- [ ] เปิดโต๊ะได้และโต๊ะเปลี่ยนเป็น `OCCUPIED`
- [ ] แก้จำนวนลูกค้าบนโต๊ะแล้วข้อมูลอัปเดตถูกสาขา
- [ ] กำหนดพนักงานเสิร์ฟได้
- [ ] ย้ายโต๊ะได้โดย session ไม่หาย
- [ ] รวมโต๊ะได้และโต๊ะต้นทางกลับเป็น `CLEANING`
- [ ] ปิดโต๊ะหลังชำระเงินแล้วโต๊ะเปลี่ยนเป็น `CLEANING`

## Reservation
- [ ] สร้างการจองโต๊ะได้
- [ ] แก้ไข, ยืนยัน, ยกเลิก, และ `no-show` ได้
- [ ] นำลูกค้าจาก reservation เข้านั่งได้
- [ ] หลัง seat แล้ว รายการจองเปลี่ยนเป็น `SEATED`
- [ ] หลัง seat แล้ว สถานะโต๊ะและ session อัปเดตทันที
- [ ] ไม่สามารถ seat การจองที่ `CANCELLED` หรือ `NO_SHOW`

## รับออเดอร์ Dine-in
- [ ] เปิดโต๊ะแล้วสร้าง order แบบ `OPEN` ได้
- [ ] order ถูกผูกกับ `table_id`, `session_id`, `service_type = DINE_IN`
- [ ] รายการ course แรกเข้า `PENDING`
- [ ] รายการ course ถัดไปเข้า `HELD`
- [ ] stock ถูกจอง (`reserved_qty`) เมื่อสร้าง order แบบ `OPEN`
- [ ] โต๊ะบันทึก `current_order_id` ถูกต้อง

## KDS และครัว
- [ ] KDS แสดงเฉพาะรายการที่ต้องเตรียม
- [ ] แยกตาม station เช่น `kitchen`, `bar`, `dessert` ถูกต้อง
- [ ] เปลี่ยนสถานะ `PENDING -> PREPARING -> READY -> SERVED` ได้
- [ ] Fire course แล้วรายการ `HELD` เปลี่ยนเป็น `PENDING`
- [ ] มีเสียง/การแจ้งเตือนเมื่อมีรายการใหม่เข้าครัว
- [ ] Kitchen summary และ analytics แสดงข้อมูลตามสาขาที่เลือก

## Billing และ Payment
- [ ] เปิดหน้า bill จากโต๊ะที่ใช้งานอยู่ได้
- [ ] ตั้ง service charge ได้และยอดรวมคำนวณถูกต้อง
- [ ] พิมพ์ pre-bill ได้
- [ ] split bill แบบเท่ากันทำงานได้
- [ ] split bill แบบเลือก item ทำงานได้
- [ ] apply split แล้วเกิด order แยกจริง
- [ ] ชำระหลาย order ในโต๊ะเดียวพร้อมกันได้
- [ ] complete payment แล้ว stock reservation ถูกคืนและ stock movement ถูกตัดจริง
- [ ] หลัง complete payment แล้ว `current_order_id` ของโต๊ะถูกล้าง

## Void และ Control
- [ ] ยกเลิกรายการอาหารต้องกรอกเหตุผล
- [ ] ถ้าตั้ง `manager PIN` ไว้ ต้องกรอก PIN ถูกต้องจึง void ได้
- [ ] ยกเลิกรายการที่ยัง `HELD` ได้
- [ ] รายการที่ถูกยกเลิกไม่กลับมาใน bill
- [ ] timeline มี event การยกเลิกรายการพร้อมเหตุผล

## Timeline และ Audit
- [ ] timeline แสดงเหตุการณ์เปิดโต๊ะ
- [ ] timeline แสดง waiter assignment
- [ ] timeline แสดง fire course
- [ ] timeline แสดงการสั่งอาหาร
- [ ] timeline แสดง item status สำคัญและการยกเลิกรายการ

## Regression
- [ ] retail/POS flow เดิมยังขายหน้าร้านได้ปกติ
- [ ] รายงานร้านอาหารไม่ดึง order retail มาปน
- [ ] branch filter ยังทำงานถูกต้องกับ restaurant pages
- [ ] `dart analyze` ผ่าน
- [ ] `flutter test test/core/server/restaurant_r4_routes_test.dart` ผ่าน
