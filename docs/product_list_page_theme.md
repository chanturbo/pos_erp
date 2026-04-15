# Theme UI — หน้ารายการสินค้า (`product_list_page.dart`)

> อ้างอิงจาก `lib/features/products/presentation/pages/product_list_page.dart`  
> และ `lib/shared/theme/app_theme.dart`
> อัปเดตล่าสุด: 2026-04-15 (rev 2)

---

## Color Tokens (`_ProductListColors`)

`_ProductListColors.of(context)` — สร้างผ่าน factory พร้อม dark-mode switching อัตโนมัติ

| Token | Light Mode | Dark Mode | ใช้ที่ไหน |
|---|---|---|---|
| `scaffoldBg` | `AppTheme.surface` `#F4F4F0` | `AppTheme.darkBg` `#121212` | พื้นหลัง Scaffold ทั้งหน้า |
| `cardBg` | `Colors.white` `#FFFFFF` | `#2C2C2C` | พื้นหลัง Card, Table container, Row |
| `border` | `AppTheme.border` `#E0E0E0` | `#333333` | เส้นแบ่ง divider, card border, chip border |
| `text` | `#1A1A1A` | `#E0E0E0` | ข้อความหลัก (ชื่อสินค้า, หน่วย) |
| `subtext` | `AppTheme.textSub` `#757575` | `#9E9E9E` | รหัสสินค้า, barcode, ต้นทุน, มูลค่า |
| `topBarBg` | `AppTheme.navy` `#16213E` | `AppTheme.navyDark` `#0D1528` | Top bar / AppBar |
| `summaryBg` | `#FFF8F5` | `#181818` | Summary bar แถวบน |
| `summaryChipBg` | `Colors.white` `#FFFFFF` | `#2C2C2C` | พื้นหลัง chip สรุปและ _ValueStat |
| `inputFill` | `Colors.white` `#FFFFFF` | `AppTheme.darkElement` `#2A2A2A` | Search field background |
| `emptyIconBg` | `AppTheme.surface` `#F4F4F0` | `AppTheme.darkCard` `#1E1E1E` | วงกลม icon ใน empty state |
| `emptyIcon` | `Colors.grey` | `#9E9E9E` | ไอคอน empty state |
| `navButtonBg` | `AppTheme.navyLight` `#1F2E54` | `rgba(white, 0.08)` | ปุ่ม toggle/filter ใน top bar |
| `navButtonBorder` | `AppTheme.navy` `#16213E` | `Colors.white24` | border ปุ่มใน top bar |
| `rowHoverBg` | `AppTheme.primaryLight` `#FF9D45` | `rgba(primaryLight, 0.15)` | พื้นหลัง row เมื่อ hover (table view) |
| `tableHeaderBg` | `AppTheme.navy` `#16213E` | `AppTheme.navyDark` `#0D1528` | พื้นหลัง header row ของตาราง |
| `headerText` | `Colors.white70` | `#E0E0E0` | ข้อความ header คอลัมน์ (ไม่ active sort) |
| `amountText` | `AppTheme.info` `#1565C0` | `AppTheme.primaryLight` `#FF9D45` | ราคาขาย, จำนวนคงเหลือ (ตัวเลขเด่น) |
| `costText` | `#666666` | `#BDBDBD` | ต้นทุน, มูลค่าคลัง (ตัวเลขรอง) |
| `rowIndexText` | `#BBBBBB` | `#8F8F8F` | เลขลำดับแถว (#) |

---

## Design Tokens จาก `AppTheme`

| Token | ค่าสี | บทบาทในหน้านี้ |
|---|---|---|
| `AppTheme.primary` | `#E57200` | ปุ่ม Active Filter (isActiveOnly), primary color ทั่วไป |
| `AppTheme.primaryLight` | `#FF9D45` | sort icon active, row hover (dark), amountText (dark) |
| `AppTheme.primaryDark` | `#AC4F00` | _ValueStat มูลค่าขาย (light → dark ใช้ primaryLight) |
| `AppTheme.navy` | `#16213E` | Top bar, table header (light), navButtonBorder |
| `AppTheme.navyDark` | `#0D1528` | Top bar, table header (dark) |
| `AppTheme.navyLight` | `#1F2E54` | navButtonBg (light) |
| `AppTheme.info` | `#1565C0` | amountText (light), Summary chip จำนวน (ทั้งคลัง) |
| `AppTheme.success` | `#2E7D32` | Badge "ใช้งาน", Summary chip ใช้งาน, กำไรคาดการณ์ |
| `AppTheme.error` | `#C62828` | Badge "ปิดใช้", Summary chip ปิดใช้, ขาดทุนคาดการณ์ |
| `AppTheme.warning` | `#F9A825` | Dialog icon "ปิดการใช้งาน" |
| `AppTheme.surface` | `#F4F4F0` | scaffoldBg (light), emptyIconBg (light) |
| `AppTheme.border` | `#E0E0E0` | border (light) |
| `AppTheme.textSub` | `#757575` | subtext (light) |
| `AppTheme.darkBg` | `#121212` | scaffoldBg (dark) |
| `AppTheme.darkCard` | `#1E1E1E` | emptyIconBg (dark) |
| `AppTheme.darkElement` | `#2A2A2A` | inputFill (dark) |
| `AppTheme.purpleColor` | `#6A1B9A` | Avatar chip ตัวอักษรบางตัว (card view) |
| `AppTheme.tealColor` | `#00695C` | Avatar chip ตัวอักษรบางตัว (card view) |

---

## Typography

| เลเยอร์ | fontSize | fontWeight | color token | ใช้ที่ไหน |
|---|---|---|---|---|
| Page title | 16 | w600 | `Colors.white` | "รายการสินค้า" ใน top bar |
| ชื่อสินค้า (table) | 13 | normal | `text` | คอลัมน์ชื่อสินค้า |
| รหัสสินค้า | 13 | w500 | `subtext` | fontFamily: monospace |
| barcode | 11 | normal | `subtext` | ใต้ชื่อสินค้า (table) |
| ราคาขาย / คงเหลือ | 13 | w600 | `amountText` | ตัวเลขเด่น |
| ต้นทุน / มูลค่า | 12 | normal | `costText` | ตัวเลขรอง |
| หน่วย | 12 | normal | `text` | คอลัมน์หน่วย |
| Header คอลัมน์ | 12 | w600 | `headerText` / orange เมื่อ active | letterSpacing: 0.4 |
| Row index (#) | 12 | normal | `rowIndexText` | เลขลำดับแถว |
| Badge สถานะ | 11 | w600 | success/error | "ใช้งาน" / "ปิดใช้" |
| Summary chip label | 11 | normal | displayColor (0.88 alpha) | ชื่อ chip ด้านซ้าย |
| Summary chip count | 11 | bold | `Colors.white` | badge จำนวนใน chip |
| _ValueStat label | 10 | normal | displayColor (0.76–0.92 alpha) | label ใต้ยอดเงิน |
| _ValueStat value | 13–14.5 | bold | displayColor | ยอดเงิน ต้นทุน/ขาย/กำไร |
| ชื่อสินค้า (card) | 13 | w600 | `text` | card view header |
| รายละเอียด (card) | 11–12 | various | `subtext` / `amountText` | card view details |

---

## Layout โครงสร้างหน้า

```
Scaffold
├── _ProductListTopBar           ← top bar สีเข้ม (navy)
├── _buildSummaryBar             ← summary chips + financial stats
└── Expanded
    ├── Container (card border, shadow)
    │   ├── [Table View]
    │   │   ├── _ProductResizableHeader   ← header row ลากปรับขนาดได้
    │   │   ├── Divider
    │   │   └── ListView → _ProductTableRow × N
    │   └── [Card View]
    │       └── ListView → Card × N
    └── PaginationBar + PdfReportButton
```

### Current UX Notes

- Desktop default เป็น `table view`
- Mobile default เป็น `card view`
- Search, warehouse filter, active-only toggle, view toggle และ action หลักทั้งหมดอยู่ใน Top Bar
- Summary bar ทำหน้าที่สรุปตัวเลขและมูลค่าหลักของสินค้า ไม่ใช้เป็น filter bar
- Table view รองรับการลากปรับความกว้างคอลัมน์และ auto-fit ตามข้อมูลจริง
- Footer ใช้ `PaginationBar` และมี `PdfReportButton` เป็น action ปลายแถว

---

## Top Bar (`_ProductListTopBar`)

| ส่วน | Widget | Style |
|---|---|---|
| Container | background | `topBarBg` (navy/navyDark) |
| Padding | horizontal 16, vertical 12 | — |
| Back button | InkWell + Icon `arrow_back` | `navButtonBg` + `navButtonBorder` |
| Page icon | Icon `inventory_2` | `Colors.white70`, size 20 |
| Page title | Text | 16px w600 white |
| Search field | TextField | `inputFill` bg, border `border` token, text `text` token |
| Warehouse dropdown | DropdownButton | style ตาม `navButtonBg`/`navButtonBorder` |
| Toggle active filter | `_PToggleBtn` | active → `AppTheme.success`, inactive → navButtonBg |
| Toggle view (table/card) | `_PToggleBtn` | active → `AppTheme.primary` |
| Refresh / Groups / Add | `_PToggleBtn` / FilledButton | แต่ละปุ่มสี info/primary |

### Responsive Behavior

- `didChangeDependencies()` กำหนดค่าเริ่มต้นให้:
  - `desktop/tablet` → table
  - `mobile` → card
- ผู้ใช้ยังสลับ view ได้เองผ่านปุ่ม toggle
- Search state, warehouse filter และ pagination ยังคงพฤติกรรมเดิมข้ามการสลับ view

### `_PToggleBtn` active styles (ตัวอย่าง)
- **isActiveOnly ON**: bg `success` 10%, border `success` 30%
- **isTableView**: bg `primary` 10%, border `primary` 30%
- **inactive**: bg `navButtonBg`, border `navButtonBorder`

---

## Summary Bar

### Summary Chips (ซ้าย)
| Chip | สี | ใช้ AppTheme |
|---|---|---|
| ทั้งหมด | น้ำเงิน | `AppTheme.info` |
| กรองแล้ว | ส้ม | `AppTheme.primary` |
| ใช้งาน | เขียว | `AppTheme.success` |
| ปิดใช้ | แดง | `AppTheme.error` |
| จำนวนคลัง | น้ำเงิน | `AppTheme.info` |

**`_SummaryChip` style:**
- Container: bg `summaryChipBg`, border `border`, radius 999
- padding: horizontal 10, vertical 5
- Badge: bg `displayColor` (full alpha), text white, radius 8, padding H6 V1

### Financial Stats (ขวา) — `_ValueStat`

| Stat | สี | Emphasis |
|---|---|---|
| ต้นทุนรวม | `AppTheme.navy` → dark: `#E0E0E0` | medium |
| มูลค่าขาย | `AppTheme.primaryDark` → dark: `primaryLight` | medium |
| กำไร/ขาดทุนคาดการณ์ | `AppTheme.success` / `AppTheme.error` → dark: `#7FD483` / `#FF8A80` | **high** |

**Emphasis levels:**
- `medium`: bg `summaryChipBg`, border `border`, padding H10 V6, value 13px
- `high`: bg `displayColor × 0.12–0.18`, border `displayColor × 0.24–0.34`, padding H12 V7, value 14.5px

**`_summaryDisplayColor` (dark mode remapping):**
| Light color | Dark color |
|---|---|
| `AppTheme.navy` | `#E0E0E0` |
| `AppTheme.primaryDark` | `AppTheme.primaryLight` (#FF9D45) |
| `AppTheme.primary` | `AppTheme.primaryLight` (#FF9D45) |
| `AppTheme.info` | `#7CB7FF` |
| `AppTheme.success` | `#7FD483` |
| `AppTheme.error` | `#FF8A80` |

---

## Table View

### Header Row (`_ProductResizableHeader`)
- Background: `tableHeaderBg` (navy/navyDark)
- Row height: 36px (icon) + vertical padding 10
- Column No. (#): fixed 48px, centered, text `Colors.white70` 12px

**ลำดับคอลัมน์และพฤติกรรม sort:**

| # | คอลัมน์ | sortKey | min / initial / max |
|---|---|---|---|
| 0 | รหัสสินค้า | `productCode` | 110 / 120 / 220 |
| 1 | ชื่อสินค้า | `productName` | 120 / 200 / 500 |
| 2 | คงเหลือ | `balance` | 96 / 100 / 140 |
| 3 | หน่วย | — | 56 / 60 / 140 |
| 4 | ราคาขาย | `priceLevel1` | 100 / 110 / 180 |
| 5 | ต้นทุน | `standardCost` | 90 / 96 / 180 |
| 6 | มูลค่า | `stockValue` | 96 / 110 / 200 |
| 7 | สถานะ | — | 72 / 76 / 120 |
| 8 | จัดการ | — | 88 / 88 / 88 |

**`_ProductResizableCell` layout:**
```
SizedBox(width)
└── Row
    ├── Expanded → GestureDetector → Padding(H8 V10)
    │   └── Row
    │       ├── Flexible → Text(overflow: ellipsis)   ← label
    │       └── [sort icon: unfold_more 12px / arrow_up/down 12px]
    └── DragHandle: 14px wide (ยกเว้นคอลัมน์สุดท้าย)
```
- Active sort: label + icon = `#FF9D45` (orange)
- Inactive sortable: icon `Colors.white38` (unfold_more)
- Non-sortable: ไม่มี icon

**Auto-fit column calculation:**
```
colWidth = textWidth + basePadding(16) + sortChrome(20 if sortable) + resizeHandle(14) + buffer(10)
```

แนวคิดปัจจุบัน:
- คอลัมน์ชื่อสินค้าเป็นคอลัมน์หลักที่ยืดหยุ่นที่สุด
- คอลัมน์ตัวเลข (`คงเหลือ / ราคา / ต้นทุน / มูลค่า`) คงโทนอ่านค่าเร็วและชิดขวา
- ถ้าผู้ใช้ resize เอง ระบบจะไม่ override ค่านั้นด้วย auto-adjust รอบถัดไป

### Data Row (`_ProductTableRow`)
- Row height: text 13px + vertical padding 10 = ~46px
- Hover: `AnimatedContainer` 120ms → bg เปลี่ยนเป็น `rowHoverBg`
- Double-tap: เปิด edit form
- แถวสลับสี: ไม่มี (ใช้ divider เส้น `border` แทน)

**Cell styles ต่อคอลัมน์:**
| คอลัมน์ | align | fontSize | fontWeight | color |
|---|---|---|---|---|
| # | center | 12 | normal | `rowIndexText` |
| รหัสสินค้า | left | 13 | w500 | `subtext`, monospace |
| ชื่อสินค้า + barcode | left | 13 / 11 | normal | `text` / `subtext` |
| คงเหลือ | right | 13 | w600 | `amountText` |
| หน่วย | center | 12 | normal | `text` |
| ราคาขาย | right | 13 | w600 | `amountText` |
| ต้นทุน | right | 12 | normal | `costText` |
| มูลค่า | right | 12 | normal | `costText` |
| สถานะ | center | — | — | `_StatusBadge` |
| จัดการ | center | — | — | `_ActionIconBtn` × 2 |

### `_StatusBadge`
- "ใช้งาน": bg `AppTheme.successContainer` `#B9F6CA`, border `success×0.18`, dot เขียว `#4CAF50`, text `#2E7D32`
- "ปิดใช้": bg `AppTheme.errorContainer` `#FFCDD2`, border `error×0.18`, dot แดง `#F44336`, text `#C62828`
- fontSize: 10, fontWeight: w600, radius 10

### `_ActionIconBtn`
- Container: 32×32, radius 8
- bg: `color × 0.08`, border: `color × 0.18`
- icon: 16px สี `color`
- แก้ไข: `AppTheme.info` `#1565C0`
- ลบ: `AppTheme.error` `#C62828`

---

## Card View (`_buildCardView`)

| ส่วน | Style |
|---|---|
| Card container | elevation 0, border `border` token, radius 10, bg `cardBg` |
| Avatar | CircleAvatar radius 20, สีหมุนเวียน 6 สี (primary/info/success/warning/purple/teal) |
| No-stock badge | วงกลม 14px บน avatar, bg `AppTheme.textSub`, icon `remove_circle_outline` 8px |
| ชื่อสินค้า | 13px w600 `text`, ellipsis |
| Status badge | เหมือน `_StatusBadge` แต่ inline (radius 10) |
| รหัสสินค้า | 11px `subtext` |
| barcode | 11px `subtext` + icon `qr_code` 11px |
| ราคา / หน่วย | 12px w700 `amountText` / 11px `subtext` |
| ต้นทุน | 11px `subtext` |
| คงเหลือ + มูลค่า | 11px `subtext` (1 บรรทัด) |

**Avatar color palette (index = `codeUnit % 6`):**
`primary` → `info` → `success` → `warning` → `purpleColor` → `tealColor`

---

## Empty State

| ส่วน | Style |
|---|---|
| Circle container | 80×80, bg `emptyIconBg`, border `border`, shape circle |
| Icon | 38px สี `emptyIcon` (`inventory_2_outlined` / `search_off_outlined`) |
| Title | 15px w500 `text` |
| Subtitle | 13px `subtext` |
| Add button | `ElevatedButton.icon` (default theme) |

---

## PDF Report (`product_pdf_report.dart`)

| ส่วน | ค่า |
|---|---|
| Page format | A4 portrait, margin 24pt ทุกด้าน |
| Header font | NotoSansThaiBold (Google Fonts) |
| Body font | NotoSansThaiRegular |
| Company name | 9pt `#555555` |
| Report title | 14pt bold black |
| Summary line | 8pt `#555555` |
| Table header bg | `#DDDDDD` |
| Alternate row bg | `#F5F5F5` |
| Border color | `#BBBBBB`, width 0.5 |

**ลำดับคอลัมน์ PDF:**

| คอลัมน์ | ความกว้าง | align |
|---|---|---|
| # | 26pt fixed | center |
| รหัสสินค้า | 68pt fixed | left |
| ชื่อสินค้า | flex (1) | left |
| คงเหลือ | 52pt fixed | right |
| หน่วย | 38pt fixed | center |
| ราคาขาย | 56pt fixed | right |
| ต้นทุน | 56pt fixed | right |
| มูลค่า | 62pt fixed | right |
| สถานะ | 40pt fixed | center |

**Financial Summary Box (header ทุกหน้า):**
- bg `#F5F5F5`, border `#BBBBBB` 0.5pt, radius 3
- padding H8 V6
- แบ่ง 3 ช่อง: ต้นทุนรวม / มูลค่าขาย / กำไรคาดการณ์
- สีกำไร: `#1B5E20` (เขียว), ขาดทุน: `#B71C1C` (แดง)

---

## การคำนวณ Dark Mode (`_summaryDisplayColor`)

ฟังก์ชันแปลงสีสำหรับ Summary bar เมื่ออยู่ใน dark mode เพื่อให้ contrast เพียงพอ:

```dart
Color _summaryDisplayColor(Color base, bool isDark) {
  if (!isDark) return base;
  return switch (base) {
    AppTheme.navy        => #E0E0E0,
    AppTheme.primaryDark => AppTheme.primaryLight,   // #FF9D45
    AppTheme.primary     => AppTheme.primaryLight,   // #FF9D45
    AppTheme.info        => #7CB7FF,
    AppTheme.success     => #7FD483,
    AppTheme.error       => #FF8A80,
    _                    => base,
  };
}
```

---

> อัปเดตล่าสุด: 2026-04-15
