# Restaurant Module Roadmap

เอกสารนี้สรุปเฉพาะแนวทางพัฒนา `Restaurant Module` สำหรับใช้งานร่วมกับระบบ `POS เดิม` ใน codebase เดียว โดย `License` ใช้ร่วมกับระบบ POS เดิมและไม่แยกออกมาเป็นอีกระบบ

## ขอบเขตของเอกสาร

เอกสารนี้ครอบคลุมเฉพาะ:

- แนวคิดการออกแบบ restaurant mode
- ขอบเขตฟีเจอร์หลัก
- data model ระดับสูง
- phase การพัฒนา
- ลำดับงานที่แนะนำ

สิ่งที่ไม่รวมในเอกสารนี้:

- roadmap ของ license
- roadmap ของ backup hardening
- เอกสารแยกระบบ POS เดิม

## แนวทางหลัก

Restaurant module ควรทำเป็น `operational mode` ภายในระบบเดิม ไม่ควรแยกเป็นอีกแอปหรืออีก repo

หลักการสำคัญ:

- ใช้ codebase เดียว
- ใช้ `License` เดิมร่วมกับระบบ POS
- ใช้ master data เดิมร่วมกัน
- แยกเฉพาะ workflow ร้านอาหาร
- ไม่ทำให้ flow ขายปลีกเดิมพัง

## สิ่งที่ใช้ร่วมกับ POS เดิมได้เลย

ฟีเจอร์แกนกลางที่ควรใช้ร่วมกัน:

- Auth
- Users / Roles
- Products
- Stock / Inventory
- Customers / Members
- Promotions
- Purchases
- AP / AR
- Reports
- Branch / Warehouse
- Settings
- Backup / Restore
- License

สรุปคือ restaurant module ไม่ควรมีฐานข้อมูลธุรกิจแยกชุดใหม่ แต่ควรต่อยอดจากของเดิมให้รองรับรูปแบบการให้บริการร้านอาหาร

## โหมดการทำงานที่ควรรองรับ

ระบบควรรองรับ 3 โหมด:

- `retail`
- `restaurant`
- `hybrid`

คำแนะนำคือให้ตั้ง `business_mode` ระดับ `สาขา` เพราะเหมาะกับการใช้งานจริงที่สุด

ตัวอย่าง:

- บางสาขาเป็น retail
- บางสาขาเป็น restaurant
- บางสาขาเป็น hybrid

## Restaurant Module ขายอะไรได้บ้าง

Restaurant module ควรรองรับได้ทั้ง:

- อาหาร
- เครื่องดื่ม
- ของหวาน
- add-on
- set menu
- service charge
- ค่าบริการพิเศษ

ความต่างจาก POS ทั่วไปไม่ใช่ชนิดสินค้า แต่เป็น workflow เช่น:

- เปิดโต๊ะ
- รับออเดอร์
- ส่งเข้าครัวหรือบาร์
- ติดตามสถานะการเตรียม
- พิมพ์ pre-bill
- split bill
- ปิดบิลต่อโต๊ะ

## Product Model ที่ควรเพิ่ม

สินค้าเดิมควรใช้ร่วมกันได้ แต่ควรเพิ่ม field เพื่อรองรับ restaurant context

- `service_mode = retail | restaurant | both`
- `prep_station = kitchen | bar | dessert | cashier`
- `requires_preparation = true | false`
- `dine_in_available = true | false`
- `takeaway_available = true | false`

ตัวอย่าง:

- ข้าวผัด -> `restaurant`, `kitchen`
- กาแฟเย็น -> `restaurant`, `bar`
- น้ำเปล่าขวด -> `both`
- ขนม packaged -> `retail` หรือ `both`

## โครงสร้างข้อมูลหลักที่ควรมี

### 1. Dining Tables

ข้อมูลที่ควรมี:

- `table_id`
- `table_no`
- `table_display_name`
- `zone_id` หรือ `zone_name`
- `seat_count`
- `branch_id`
- `is_active`
- `table_status`

สถานะโต๊ะที่แนะนำ:

- `available`
- `occupied`
- `reserved`
- `cleaning`
- `disabled`

### 2. Table Sessions

ควรมี entity สำหรับรอบการใช้งานของโต๊ะ

- `session_id`
- `table_id`
- `branch_id`
- `opened_at`
- `closed_at`
- `guest_count`
- `status`
- `opened_by`

สถานะที่แนะนำ:

- `open`
- `billed`
- `closed`
- `cancelled`

### 3. Restaurant Orders

ควร reuse sales/order เดิมให้มากที่สุด แล้วเพิ่ม field เฉพาะร้านอาหาร

- `service_type = dine_in | takeaway | delivery`
- `table_id`
- `session_id`
- `guest_count`
- `kitchen_status`
- `course_status`

### 4. Kitchen / Bar Queue

ควรมี queue สำหรับงานหลังบ้าน

- `queue_id`
- `order_id`
- `order_item_id`
- `prep_station`
- `queue_status`
- `queued_at`
- `started_at`
- `ready_at`
- `served_at`

สถานะที่แนะนำ:

- `pending`
- `preparing`
- `ready`
- `served`
- `cancelled`

## หน้าจอหลักที่ควรมี

### 1. Table Overview

หน้าดูภาพรวมโต๊ะทั้งหมด

ควรมี:

- grid โต๊ะ
- สีตามสถานะโต๊ะ
- จำนวนลูกค้า
- เวลาเปิดโต๊ะ
- ยอดรวมโดยประมาณ

action หลัก:

- เปิดโต๊ะ
- เข้าโต๊ะ
- ย้ายโต๊ะ
- รวมโต๊ะ
- ปิดโต๊ะ

### 2. Restaurant Order Page

หน้ารับออเดอร์สำหรับโต๊ะหรือ dine-in

ควรมี:

- เลือกโต๊ะ
- เพิ่มอาหารและเครื่องดื่ม
- แยกหมวดสินค้า
- note ต่อรายการ
- modifier / add-on
- hold / send order

### 3. Kitchen Display System

ควรมี:

- รายการที่รอทำ
- filter ตาม station
- ปุ่มเปลี่ยนสถานะ
- เวลา waiting time

station ขั้นต้น:

- kitchen
- bar

### 4. Billing Page

ควรมี:

- สรุปรายการทั้งโต๊ะ
- pre-bill
- split bill
- merge bill
- discount
- service charge
- final payment

## Phase การพัฒนา

### Phase R0: Preparation

เป้าหมาย:

- เตรียม model และ config ให้พร้อมสำหรับ restaurant mode

งานหลัก:

- เพิ่ม `business_mode`
- เพิ่ม field สินค้าใน restaurant context
- สำรวจ schema เดิมที่มีอยู่แล้ว เช่น `dining_tables`, `table_id`, `kitchen_status`
- กำหนดขอบเขต MVP

ผลลัพธ์:

- ระบบพร้อมเริ่ม restaurant flow โดยไม่ชนกับ retail เดิม

### Phase R1: Table Service MVP

เป้าหมาย:

- เปิดใช้งานร้านอาหารแบบพื้นฐานได้จริง

scope:

- จัดการโต๊ะ
- เปิดโต๊ะ
- รับออเดอร์แบบ dine-in
- ผูกออเดอร์กับโต๊ะ
- ย้ายโต๊ะ
- ปิดโต๊ะหลังชำระเงิน

หน้าหลักที่ควรมี:

- `Table Overview`
- `Open Table Order`
- `Transfer Table`
- `Close Table`

ผลลัพธ์:

- ร้านสามารถรับลูกค้านั่งโต๊ะและปิดบิลได้จริง

### Phase R2: Kitchen / Bar Workflow

เป้าหมาย:

- รองรับงานครัวและบาร์เป็นระบบ

scope:

- ส่งรายการเข้า station
- KDS สำหรับครัว
- KDS สำหรับบาร์
- เปลี่ยนสถานะ `pending > preparing > ready > served`

ผลลัพธ์:

- ครัวและบาร์ทำงานต่อจาก POS ได้ชัดเจน

### Phase R3: Billing Flow

เป้าหมาย:

- รองรับการคิดเงินแบบร้านอาหารจริง

scope:

- pre-bill
- split bill
- merge bill
- service charge
- note / modifier ต่อจาน

ผลลัพธ์:

- หน้าร้านใช้งานได้สมบูรณ์ขึ้น

### Phase R4: Advanced Restaurant Operations

scope:

- reservation
- waiter assignment
- course / fire order
- table timeline
- kitchen analytics
- restaurant-specific reporting

ผลลัพธ์:

- รองรับร้านที่มี operation ซับซ้อนขึ้น

## ลำดับการพัฒนาที่แนะนำ

แนะนำลำดับดังนี้:

1. `R0 Preparation`
2. `R1 Table Service MVP`
3. `R2 Kitchen / Bar Workflow`
4. `R3 Billing Flow`
5. `R4 Advanced Operations`

เหตุผล:

- ถ้ายังไม่มี table/session ที่ชัดเจน ระบบ restaurant จะซับซ้อนเร็วมาก
- ถ้ากระโดดไปทำ KDS หรือ split bill ก่อน โครงสร้างหลักจะไม่นิ่ง

## สิ่งที่ควร reuse จากระบบเดิม

ควร reuse:

- product master
- stock movement
- branch / warehouse
- customer / member
- promotion engine
- sales order structure เท่าที่ใช้ได้
- payment flow เดิม
- report engine เดิม

ควรต่อยอดเพิ่ม:

- table session
- restaurant order metadata
- kitchen queue
- dine-in billing

## สิ่งที่ไม่แนะนำ

- แยก restaurant เป็นอีก app
- แยกฐานข้อมูล restaurant ออกจาก POS เดิม
- ทำ reservation, KDS, split bill, waiter assignment พร้อมกันตั้งแต่รอบแรก
- แยก product master ระหว่าง retail กับ restaurant

## MVP ที่แนะนำที่สุด

ถ้าต้องการเริ่มเร็วและไม่หลุดทิศทาง:

- ใช้ `restaurant mode` ระดับสาขา
- มีหน้าจอ `Table Overview`
- เปิดโต๊ะและสร้าง order ได้
- เพิ่มอาหารและเครื่องดื่มได้
- ปิดบิลและปิดโต๊ะได้

สิ่งที่ยังไม่จำเป็นใน MVP รอบแรก:

- reservation
- split bill แบบซับซ้อน
- merge table ขั้นสูง
- course control
- KDS หลาย station แบบละเอียด

## สรุป

Restaurant module ควรเป็นส่วนขยายของระบบ POS เดิม ไม่ใช่ระบบใหม่อีกตัว

แนวทางที่แนะนำที่สุดคือ:

- ใช้ codebase เดียว
- ใช้ `License` เดิมร่วมกับ POS
- เปิดโหมดตามสาขา
- เริ่มจาก `R0 -> R1 -> R2 -> R3 -> R4`
- ลงมือจริงจาก `Table Service MVP` ก่อน แล้วค่อยขยาย
