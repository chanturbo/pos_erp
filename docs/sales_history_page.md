# Theme UI Summary — `sales_history_page.dart`

> อ้างอิงจาก `lib/features/sales/presentation/pages/sales_history_page.dart`  
> และ `lib/shared/theme/app_theme.dart`  
> อัปเดตล่าสุด: 2026-04-15

---

## ฟอนต์

- **IBM Plex Sans Thai** (fallback: Sarabun) — ใช้ผ่าน theme กลางของแอป

---

## สีหลัก (Design Tokens)

| Token | ชื่อ | ค่าสี | ใช้ที่ไหน |
|---|---|---|---|
| `AppTheme.primary` | OAG Orange | `#E57200` | focus border, action icon, highlight row |
| `AppTheme.primaryLight` | Orange Light | `#FF9D45` | badge ใน top bar, amount text ใน Dark mode |
| `AppTheme.navy` | Navy | `#16213E` | top bar, table header (Light) |
| `AppTheme.navyDark` | Navy Dark | `#0D1528` | top bar, table header, pagination footer (Dark) |
| `AppTheme.surface` | Neutral BG | `#F4F4F0` | scaffold background (Light) |
| `AppTheme.border` | Border | `#E0E0E0` | เส้นแบ่ง, border card, input, chip |
| `AppTheme.textSub` | Subtext | `#757575` | ข้อความรอง, metadata, placeholder |
| `AppTheme.info` | Blue | `#1565C0` | summary chip count, payment badge, amount text (Light) |
| `AppTheme.infoContainer` | Blue BG | `#E3F2FD` | พื้นหลัง payment badge แบบบัตร |
| `AppTheme.success` | Green | `#2E7D32` | สถานะสำเร็จ, payment เงินสด |
| `AppTheme.error` | Red | `#C62828` | error state, สถานะยกเลิก |
| `AppTheme.warning` | Yellow | `#F9A825` | สถานะ pending |

---

## Top Bar

| โหมด | Background | Text / Icon |
|---|---|---|
| **Light** | `AppTheme.navy` | `Colors.white`, `Colors.white70` |
| **Dark** | `AppTheme.navyDark` | `Colors.white`, `Colors.white70` |

- padding: `horizontal 16, vertical 12`
- title: `ประวัติการขาย`
- title style: `fontSize 16`, `fontWeight w600`
- page icon: `Icons.history`
- มี label badge `Sales History`

### ปุ่มใน Top Bar

- Back / Refresh: BG `AppTheme.navyLight` ใน Light, `white @ 8%` ใน Dark
- Border: `AppTheme.navy` ใน Light, `white24` ใน Dark
- Icon: `Colors.white70`
- Clear filter button: BG `white @ 8%`, border `white24`, text/icon `white`

---

## Responsive Breakpoints

| ความกว้าง | Layout |
|---|---|
| `>= 600px` (Tablet / Desktop) | Filter chips ย้ายเข้า Summary Bar (inline) — `_FilterBar` ถูกซ่อน |
| `< 600px` (Mobile) | `_FilterBar` แยกแถวปกติใต้ Top Bar |

---

## Search / Filter Bar (Mobile เท่านั้น)

> แสดงเฉพาะหน้าจอ `< 600px`

| โหมด | Background |
|---|---|
| **Light** | `Colors.white` |
| **Dark** | `AppTheme.darkTopBar` (`#1E1E1E`) |

- filter bar มี bottom border `AppTheme.border` หรือ dark border `#333333`
- search field height: `40px`
- search field radius: `8px`
- enabled border: `AppTheme.border`
- focused border: `AppTheme.primary`, `1.5px`
- fill: `Colors.white` ใน Light, `AppTheme.darkElement` ใน Dark
- prefix icon: `Icons.search`
- suffix icon: `Icons.clear` เมื่อมีข้อความค้นหา

### Filter Chips

- Date chip / Dropdown chip
- Active state:
  - BG: `AppTheme.primary @ 8%`
  - Border: `AppTheme.primary`
  - Text/Icon: `AppTheme.primary`
- Inactive state:
  - BG: `#F0F0F0` ใน Light, `#2A2A2A` ใน Dark
  - Border: `AppTheme.border` หรือ dark border
  - Text/Icon: subtext

---

## Summary Bar

- Background:
  - Light: `#FFF8F5`
  - Dark: `#181818`
- padding: `horizontal 16, vertical 10`

### Layout ตาม Breakpoint

**Desktop / Tablet (`>= 600px`)**
- ใช้ `LayoutBuilder + SingleChildScrollView(horizontal) + ConstrainedBox + Row(spaceBetween)`
- ซ้าย: Summary chips (รายการ / สำเร็จ / จำนวนเงิน)
- ขวา: Filter chips inline (ตั้งแต่วันที่ / ถึงวันที่ / ทุกประเภทชำระ / ทุกสถานะ)
- ถ้าหน้าจอแคบกว่าความกว้าง chips รวม → เลื่อนแนวนอนได้ ไม่ overflow

**Mobile (`< 600px`)**
- ใช้ `Wrap` แสดงเฉพาะ summary chips — filter อยู่ใน `_FilterBar` แยกแถว

### Summary Chips

- shape: pill (`borderRadius 999`)
- BG: `Colors.white` ใน Light, `#2C2C2C` ใน Dark
- Border: `AppTheme.border` หรือ dark border
- icon/text size: `14 / 12`
- text weight: `w600`

รายการที่แสดง:

- จำนวนทั้งหมด: `Icons.receipt_long`, สี `AppTheme.info`
- สำเร็จ: `Icons.check_circle_outline`, สี `AppTheme.success`
- ยอดรวม: `Icons.attach_money`, สี `AppTheme.primary`

---

## Main Card / Table

- outer card:
  - BG: `Colors.white` ใน Light, `AppTheme.darkCard` ใน Dark
  - Radius: `12`
  - Border: `AppTheme.border` หรือ dark border
  - Shadow: มีเฉพาะ Light mode (`navy @ 4%`)

### Table Header

- Background:
  - Light: `AppTheme.navy`
  - Dark: `AppTheme.navyDark`
- row height: `40`
- text:
  - active sort: `#FF9D45`
  - inactive: `Colors.white70` หรือ dark text
- resize handle:
  - hover: `#FF9D45`
  - idle: `Colors.white24`

### Table Row

- default BG:
  - Light: `Colors.white`
  - Dark: `AppTheme.darkCard`
- hover BG:
  - Light: `AppTheme.primary @ 5%`
  - Dark: `AppTheme.primary @ 10%`
- horizontal padding: `16`
- vertical padding: `10`

### Column Details

- วันที่-เวลา: `fontSize 12`, subtext
- เลขที่ใบขาย: `fontSize 13`, `w600`
- ลูกค้า:
  - มีลูกค้า: icon `Icons.person_outline`
  - ไม่มีลูกค้า: แสดง `Walk-in`
- ชำระด้วย: ใช้ `_PaymentBadge`
- ยอดรวม:
  - ชิดขวา
  - `fontSize 13`, `w700`
  - Light: `AppTheme.info`
  - Dark: `AppTheme.primaryLight`
  - cancelled: ใช้สีเทาและ `line-through`
- สถานะ: ใช้ `_StatusBadge`
- ดูรายละเอียด:
  - icon `Icons.open_in_new`
  - BG `AppTheme.primary @ 8%`
  - Border `AppTheme.primary @ 18%`

---

## Payment Badge

- shape: rounded `10`
- padding: `horizontal 8, vertical 3`
- มี border สีเดียวกับ text ที่ opacity ต่ำ

| Type | Text | Text Color | Background |
|---|---|---|---|
| `CASH` | เงินสด | `AppTheme.success` | `AppTheme.successContainer` |
| `CARD` | บัตร | `AppTheme.info` | `AppTheme.infoContainer` |
| `TRANSFER` | โอน | `#6A1B9A` | `#F3E5F5` |
| default | raw value | `AppTheme.textSub` | neutral chip bg |

---

## Status Badge

- shape: rounded `12`
- padding: `horizontal 8, vertical 4`
- มี dot indicator ด้านซ้าย
- มี border สีเดียวกับสถานะที่ opacity ต่ำ

| Status | Label | Color | Background |
|---|---|---|---|
| `COMPLETED` | สำเร็จ | `AppTheme.success` | `AppTheme.successContainer` |
| `PENDING` | รอดำเนินการ | `AppTheme.warning` | `#FFF8E1` |
| `CANCELLED` | ยกเลิก | `AppTheme.error` | `AppTheme.errorContainer` |
| default | raw value | `AppTheme.textSub` | neutral chip bg |

---

## Empty State

- แสดงใน card เดียวกับหน้า
- วงกลม icon:
  - size `80x80`
  - BG `AppTheme.surface` ใน Light, `AppTheme.darkCard` ใน Dark
  - Border `AppTheme.border` หรือ dark border
- icon: `Icons.inventory_2_outlined`, size `38`
- ข้อความหลัก: `fontSize 15`, `w500`
- ข้อความรอง: `fontSize 13`, subtext
- ปุ่มล้างตัวกรอง: `ElevatedButton.icon` เมื่อมี filter

---

## Error State

- icon: `Icons.error_outline`
- size: `64`
- color: `AppTheme.error`
- ข้อความ error ใช้สีข้อความหลักของ theme
- ปุ่มลองใหม่: `ElevatedButton.icon`

---

## Pagination / Footer (`PaginationBar`)

- ใช้ `PaginationBar` กลางของระบบ (`lib/shared/widgets/pagination_bar.dart`)
- trailing widget เป็น `PdfReportButton`
- export PDF ใช้ข้อมูล `filtered` ตามที่เห็นบนหน้าจอ

### Dark Mode

| จุด | Light | Dark |
|---|---|---|
| พื้นหลัง | `AppTheme.headerBg` (`#F9F9F9`) | `AppTheme.navyDark` (`#0D1528`) — เดียวกับ title bar |
| ข้อความ "แสดง X–Y จาก Z" | `AppTheme.textSub` | `white60` |
| จุด ellipsis `...` | `AppTheme.textSub` | `white38` |
| ปุ่ม ◀▶ (enabled) BG | `Colors.white` | `white @ 10%` |
| ปุ่ม ◀▶ (enabled) border | `AppTheme.border` | `white @ 22%` |
| ปุ่ม ◀▶ icon | `Colors.black87` | `Colors.white` |
| ปุ่ม ◀▶ (disabled) icon | `AppTheme.textSub` | `white24` |
| ปุ่มเลขหน้า (inactive) BG | `Colors.white` | `white @ 10%` |
| ปุ่มเลขหน้า (inactive) border | `AppTheme.border` | `white @ 22%` |
| ปุ่มเลขหน้า (inactive) text | `Colors.black87` | `Colors.white` |
| ปุ่มเลขหน้า (active) | `AppTheme.primary` + white | เดิม (ไม่เปลี่ยน) |

---

## Dark Mode — Surface Colors

| Token / ค่าสี | ใช้ที่ไหน |
|---|---|
| `AppTheme.darkBg` `#121212` | Scaffold background |
| `AppTheme.darkCard` `#1E1E1E` | Main card, row, empty state surface |
| `#2C2C2C` | Summary chip BG (dark) |
| `#2A2A2A` | Neutral chip BG / Input fill (dark) |
| `#181818` | Summary Bar background (dark) |
| `AppTheme.darkTopBar` `#1E1E1E` | Filter Bar background (mobile dark) |
| `AppTheme.navyDark` `#0D1528` | Top bar, Table header, Pagination footer (dark) |
| `#333333` | border ทุกจุดใน dark mode |
| `#E0E0E0` | ข้อความหลัก (dark) |
| `#9E9E9E` | ข้อความรอง (dark) |

---

## โครงสร้าง Widget หลัก

- `_SalesHistoryTopBar`
- `_FilterBar` *(แสดงเฉพาะ mobile < 600px)*
- `_SummaryBar` *(รวม inline filter chips บน tablet/desktop)*
- `_SalesTableHeader`
- `_SalesOrderRow`
- `_PaymentBadge`
- `_StatusBadge`
- `_SearchField`
- `_SalesHistoryColors`
