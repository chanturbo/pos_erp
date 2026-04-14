# Theme UI Summary — `sales_history_page.dart`

> อ้างอิงจาก `lib/features/sales/presentation/pages/sales_history_page.dart`  
> และ `lib/shared/theme/app_theme.dart`

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
| `AppTheme.navyDark` | Navy Dark | `#0D1528` | top bar, table header (Dark) |
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

## Search / Filter Bar

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
  - BG: `#F5F5F5` ใน Light, `AppTheme.darkElement` ใน Dark
  - Border: `AppTheme.border` หรือ dark border
  - Text/Icon: subtext

---

## Summary Bar

- Background:
  - Light: `#FFF8F5`
  - Dark: `AppTheme.darkTopBar`
- padding: `horizontal 16, vertical 10`
- ใช้ `Wrap` เพื่อรองรับหน้าจอแคบ

### Summary Chips

- shape: pill (`borderRadius 999`)
- BG: `Colors.white` ใน Light, `AppTheme.darkElement` ใน Dark
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

## Pagination / Footer

- ใช้ `PaginationBar` กลางของระบบ
- trailing widget เป็น `PdfReportButton`
- export PDF ใช้ข้อมูล `filtered` ตามที่เห็นบนหน้าจอ

---

## Dark Mode — Surface Colors

| Token | ค่าสี | ใช้ที่ไหน |
|---|---|---|
| `AppTheme.darkBg` | `#121212` | Scaffold background |
| `AppTheme.darkCard` | `#1E1E1E` | Main card, row, empty state surface |
| `AppTheme.darkElement` | `#2A2A2A` | Input fill, chip inactive, summary chip |
| `AppTheme.darkTopBar` | `#1E1E1E` | Filter / summary surface |
| dark border | `#333333` | border ทุกจุดใน dark mode |
| dark text | `#E0E0E0` | ข้อความหลัก |
| dark subtext | `#9E9E9E` | ข้อความรอง |

---

## โครงสร้าง Widget หลัก

- `_SalesHistoryTopBar`
- `_FilterBar`
- `_SummaryBar`
- `_SalesTableHeader`
- `_SalesOrderRow`
- `_PaymentBadge`
- `_StatusBadge`
- `_SearchField`
- `_SalesHistoryColors`
