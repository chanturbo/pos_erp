# Theme UI Summary — `product_list_page.dart`

> อ้างอิงจาก `lib/features/products/presentation/pages/product_list_page.dart`  
> และ `lib/shared/theme/app_theme.dart`

---

## ฟอนต์

- **IBM Plex Sans Thai** (fallback: Sarabun) — ใช้ผ่าน theme กลางของแอป

---

## สีหลัก (Design Tokens)

| Token | ชื่อ | ค่าสี | ใช้ที่ไหน |
|---|---|---|---|
| `AppTheme.primary` | OAG Orange | `#E57200` | ปุ่มเพิ่มสินค้า, highlight, summary chip กรองแล้ว |
| `AppTheme.primaryLight` | Orange Light | `#FF9D45` | badge `Products`, amount text ใน Dark mode |
| `AppTheme.primaryDark` | Orange Dark | `#AC4F00` | มูลค่าขายใน Light mode |
| `AppTheme.navy` | Navy | `#16213E` | top bar, table header (Light), ต้นทุนรวม (Light) |
| `AppTheme.navyDark` | Navy Dark | `#0D1528` | top bar, table header (Dark) |
| `AppTheme.surface` | Neutral BG | `#F4F4F0` | scaffold background (Light) |
| `AppTheme.border` | Border | `#E0E0E0` | border card, divider, input, summary chip |
| `AppTheme.textSub` | Subtext | `#757575` | metadata, barcode, placeholder |
| `AppTheme.info` | Blue | `#1565C0` | จำนวนทั้งหมด, ราคาขาย (Light), action edit |
| `AppTheme.success` | Green | `#2E7D32` | สถานะใช้งาน, กำไร |
| `AppTheme.error` | Red | `#C62828` | สถานะปิดใช้, ลบ, ขาดทุน |
| `AppTheme.warning` | Yellow | `#F9A825` | อยู่ใน avatar palette / reserved |

---

## Top Bar

| โหมด | Background | Text / Icon |
|---|---|---|
| **Light** | `AppTheme.navy` | `Colors.white`, `Colors.white70` |
| **Dark** | `AppTheme.navyDark` | `Colors.white`, `Colors.white70` |

- padding: `horizontal 16, vertical 12`
- title: `รายการสินค้า`
- title style: `fontSize 16`, `fontWeight w600`
- page icon: `Icons.inventory_2_outlined`
- มี label badge `Products`

### ปุ่มใน Top Bar

- Back / Refresh / Toggle / compact buttons:
  - Light: BG `AppTheme.navyLight`, border `AppTheme.navy`
  - Dark: BG `white @ 8%`, border `white24`
  - icon/text: `Colors.white70`
- ปุ่มเพิ่มสินค้า:
  - normal: filled orange
  - compact: navy-style button ตาม top bar
- ปุ่มหมวดสินค้า:
  - normal: outlined orange
  - compact: navy-style button ตาม top bar
- active toggle:
  - BG `activeColor @ 10%`
  - border `activeColor`
  - icon `activeColor`

---

## Search Bar

- อยู่ใน top bar
- text field height: `40px`
- radius: `8px`
- fill:
  - Light: `Colors.white`
  - Dark: `AppTheme.darkElement`
- enabled border: `AppTheme.border` หรือ dark border
- focused border: `AppTheme.primary`, `1.5px`
- prefix icon: `Icons.search`
- suffix icon: `Icons.clear`

---

## Summary Bar

- Background:
  - Light: `#FFF8F5`
  - Dark: `AppTheme.darkTopBar`
- มี bottom border
- padding: `fromLTRB(16, 0, 16, 10)`

### แถว 1 — Count Chips

ใช้ `_SummaryChip`

- shape: pill (`borderRadius 999`)
- BG: `Colors.white` ใน Light, `AppTheme.darkElement` ใน Dark
- border: `AppTheme.border` หรือ dark border
- ความเด่น: intentionally เบากว่า value stats เพื่อเป็นข้อมูลรอง

รายการ:

- `ทั้งหมด` → `AppTheme.info`
- `กรองแล้ว` → `AppTheme.primary`
- `ใช้งาน` → `AppTheme.success`
- `ปิดใช้` → `AppTheme.error`

### แถว 2 — Value Stats

ใช้ `_ValueStat`

- shape: pill (`borderRadius 999`)
- จัดระดับความเด่น 2 ระดับผ่าน `_ValueStatEmphasis`

ระดับความเด่น:

- `medium`
  - ใช้กับ `ต้นทุนรวม`, `มูลค่าขาย`
  - BG ใกล้เคียง summary chip ปกติ
  - ขนาดตัวเลข `13`
- `high`
  - ใช้กับ `กำไรคาดการณ์ / ขาดทุนคาดการณ์`
  - BG tint ตามสีสถานะ
  - border เด่นกว่า
  - ขนาดตัวเลข `14.5`
  - padding มากขึ้นเล็กน้อย

### Summary Hierarchy

ลำดับความเด่นสำหรับการอ่านเร็ว:

1. `กำไรคาดการณ์ / ขาดทุนคาดการณ์` — เด่นสุด
2. `มูลค่าขาย / ต้นทุนรวม` — เด่นกลาง
3. `ทั้งหมด / กรองแล้ว / ใช้งาน / ปิดใช้` — เบาสุดในชุด summary

### Dark Mode Color Balancing

สี summary ใน Dark mode ถูก remap ผ่าน `_summaryDisplayColor(...)`

- `AppTheme.navy` → `#E0E0E0`
- `AppTheme.primary / AppTheme.primaryDark` → `AppTheme.primaryLight`
- `AppTheme.info` → `#7CB7FF`
- `AppTheme.success` → `#7FD483`
- `AppTheme.error` → `#FF8A80`

เป้าหมายคือให้ทุกตัวอ่านได้ชัด แต่ยังรักษา hierarchy:

- count chips เบากว่า
- value stats ชัดกว่า
- profit/loss เด่นสุด

---

## Main Card / Content Wrapper

- ห่อทั้ง table view / card view
- BG:
  - Light: `Colors.white`
  - Dark: `AppTheme.darkCard`
- Radius: `12`
- Border: `AppTheme.border` หรือ dark border
- Shadow: มีเฉพาะ Light mode (`navy @ 4%`)

---

## Table View

### Table Header

- Background:
  - Light: `AppTheme.navy`
  - Dark: `AppTheme.navyDark`
- sort active color: `#FF9D45`
- sort inactive: `Colors.white70` หรือ dark text
- resize handle:
  - hover: `#FF9D45`
  - idle: `Colors.white24`
- มี reset button ด้านท้าย

### Table Row

- default BG:
  - Light: `Colors.white`
  - Dark: `AppTheme.darkCard`
- hover BG:
  - Light: `AppTheme.primary @ 5%`
  - Dark: `AppTheme.primary @ 10%`

### Column Details

- `#`
  - ใช้ `rowIndexText`
- `รหัสสินค้า`
  - monospace, subtext
- `ชื่อสินค้า`
  - ข้อความหลัก
  - barcode เป็นข้อความรอง
- `หน่วย`
  - ใช้ข้อความหลัก
- `ราคาขาย`
  - ชิดขวา
  - Light: `AppTheme.info`
  - Dark: `AppTheme.primaryLight`
- `ต้นทุน`
  - ชิดขวา
  - ใช้ `costText`
- `สต๊อก`
  - `Icons.inventory_2` เมื่อควบคุมสต๊อก
  - `Icons.remove` เมื่อไม่ควบคุม
- `สถานะ`
  - badge เขียว/แดง
- `จัดการ`
  - edit / delete ใช้ `_ActionIconBtn`

### Action Icon Button

- size: `32x32`
- BG: `color @ 8%`
- Border: `color @ 18%`
- radius: `8`
- icon size: `16`

---

## Card View

- ใช้ `Card` ภายใน main content card
- card BG:
  - Light: `Colors.white`
  - Dark: `AppTheme.darkCard`
- border: `AppTheme.border` หรือ dark border
- margin: `0`

องค์ประกอบ:

- avatar สีสุ่มจาก palette ตามชื่อสินค้า
- badge ไม่ควบคุมสต๊อกใช้ icon เล็กบน avatar
- status badge:
  - active: `AppTheme.successContainer`
  - inactive: `AppTheme.errorContainer`
  - มี border opacity ต่ำ
- ชื่อสินค้าใช้ข้อความหลัก
- รหัส, barcode, หน่วย, ต้นทุน ใช้ข้อความรอง
- ราคาขายใช้ `amountText`

---

## Empty State

- วงกลม icon:
  - size `80x80`
  - BG `AppTheme.surface` ใน Light, `AppTheme.darkCard` ใน Dark
  - Border `AppTheme.border` หรือ dark border
- icon:
  - `Icons.inventory_2_outlined` เมื่อไม่มีสินค้า
  - `Icons.search_off_outlined` เมื่อไม่พบผลค้นหา
- ข้อความหลัก: `fontSize 15`, `w500`
- ข้อความรอง: `fontSize 13`, subtext
- ปุ่มเพิ่มสินค้า: `ElevatedButton.icon`

---

## Error State

- icon: `Icons.error_outline`
- size: `64`
- color: `AppTheme.error`
- ข้อความใช้สีหลักของ theme
- ปุ่มลองใหม่: `ElevatedButton.icon`

---

## Pagination / Footer

- ใช้ `PaginationBar` กลางของระบบ
- trailing widget เป็น `PdfReportButton`
- export PDF ใช้ข้อมูล `filtered`
- มีการคำนวณ `totalCost`, `totalSelling`, `totalProfit` จาก stock balance ที่โหลดมา

---

## Dark Mode — Surface Colors

| Token | ค่าสี | ใช้ที่ไหน |
|---|---|---|
| `AppTheme.darkBg` | `#121212` | Scaffold background |
| `AppTheme.darkCard` | `#1E1E1E` | Main card, table row, card view, empty state surface |
| `AppTheme.darkElement` | `#2A2A2A` | Search fill, summary chip, inactive element |
| `AppTheme.darkTopBar` | `#1E1E1E` | Summary surface / top section |
| dark border | `#333333` | border ทุกจุดใน dark mode |
| dark text | `#E0E0E0` | ข้อความหลัก |
| dark subtext | `#9E9E9E` | ข้อความรอง |

---

## โครงสร้าง Widget หลัก

- `_ProductListTopBar`
- `_PSearchField`
- `_PToggleBtn`
- `_PRefreshBtn`
- `_PManageGroupsBtn`
- `_PAddBtn`
- `_ProductResizableHeader`
- `_ProductTableRow`
- `_StatusBadge`
- `_ActionIconBtn`
- `_ValueStat`
- `_SummaryChip`
- `_ProductListColors`
