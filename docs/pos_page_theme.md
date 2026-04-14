# Theme UI Summary — `pos_page.dart`

> อ้างอิงจาก `lib/features/sales/presentation/pages/pos_page.dart`  
> และ `lib/shared/theme/app_theme.dart`

---

## ฟอนต์

- **IBM Plex Sans Thai** (fallback: Sarabun) — ใช้ทั้งหน้าผ่าน `GoogleFonts.ibmPlexSansThaiTextTheme`

---

## สีหลัก (Design Tokens)

| Token | ชื่อ | ค่าสี | ใช้ที่ไหน |
|---|---|---|---|
| `AppTheme.primary` | OAG Orange | `#E57200` | ปุ่มหลัก, badge รายการ, border focus |
| `AppTheme.primaryLight` | Orange Light | `#FF9D45` | ชื่อ cashier badge, primary ใน Dark mode |
| `AppTheme.navy` | Navy | `#16213E` | AppBar background (Light) |
| `AppTheme.navyDark` | Navy Dark | `#0D1528` | AppBar background (Dark) |
| `AppTheme.surface` | Neutral BG | `#F4F4F0` | `Scaffold.backgroundColor` |
| `AppTheme.border` | Border | `#E0E0E0` | เส้นแบ่ง, chip border, divider |
| `AppTheme.textSub` | Subtext | `#757575` | ข้อความรอง (empty state) |
| `AppTheme.info` | Blue | `#1565C0` | chip ลูกค้าที่เลือกแล้ว |
| `AppTheme.infoContainer` | Blue BG | `#E3F2FD` | พื้นหลัง chip ลูกค้าที่เลือกแล้ว |
| `AppTheme.error` | Red | `#C62828` | SnackBar สแกนไม่พบ, error state |
| `AppTheme.success` | Green | `#2E7D32` | SnackBar สแกนสำเร็จ |
| `AppTheme.warning` | Yellow | `#F9A825` | Dialog icon อัพเดทราคา |

---

## AppBar

| โหมด | Background | Text / Icon | หมายเหตุ |
|---|---|---|---|
| **Light** | `#16213E` (Navy) | `Colors.white` | ทุกหน้าจอ |
| **Dark** | `#0D1528` (Navy Dark) | `#E0E0E0` | ทุกหน้าจอ |

- `centerTitle: true`, `elevation: 0`
- Title style: `fontSize 18, fontWeight w600`

---

## Chips ใน AppBar / Bottom Bar

### chip ลูกค้าทั่วไป (Walk-in)

- BG: `#1F2E54` (Navy Light) — hardcoded ทั้ง Light/Dark
- Border: `AppTheme.navy` (`#16213E`)
- ข้อความ / ไอคอน: `Colors.white70` / `Colors.white60`
- Radius: `20`

### chip ลูกค้าที่เลือกแล้ว

- BG: `AppTheme.infoContainer` (`#E3F2FD`)
- Border: `AppTheme.info @ 50% opacity` (`#1565C0`)
- ข้อความ / ไอคอน: `AppTheme.info` (`#1565C0`)
- มีปุ่ม ✕ ลบลูกค้า (สี `AppTheme.info`)

### chip สาขา (ตั้งค่าแล้ว)

- BG: `AppTheme.border @ 25% opacity`
- ไม่มี border
- ข้อความ: default ตาม theme
- ไอคอน: `Icons.storefront_outlined`, size 13

### chip ตั้งค่าสาขา (ยังไม่ได้ตั้ง)

- BG: `Colors.orange @ 10%`
- Border: `Colors.orange @ 40%`
- ข้อความ / ไอคอน: `Colors.orange`
- ไอคอน: `Icons.warning_amber_rounded`

### chip รายการ (item count)

- BG: `AppTheme.primary` (`#E57200`)
- Shape: pill — `borderRadius 999`
- ข้อความ: `Colors.white, bold, fontSize 12`
- แสดงเฉพาะเมื่อ `cartState.itemCount > 0`

---

## Search Toolbar

| โหมด | Background |
|---|---|
| **Light** | `Colors.white` |
| **Dark** | `AppTheme.darkTopBar` (`#1E1E1E`) |

- padding: `fromLTRB(16, 10, 16, 10)`
- Border bottom: `AppTheme.border`
- ความสูง TextField: `40px` (fixed)

### TextField

- Border: `radius 8, color: AppTheme.border`
- Focus border: `AppTheme.primary (#E57200), width 1.5`
- Prefix: `Icons.search, size 18`
- Suffix: ปุ่ม clear (`Icons.clear`) หรือ ScannerButton

### ปุ่มบิลที่พัก (Hold Orders)

- Icon: `Icons.folder_outlined`
- Badge count: `AppTheme.primary`, วงกลม `16x16`, ข้อความ `fontSize 10, white, bold`

---

## SnackBar

| สถานการณ์ | สี | ความกว้าง | ระยะเวลา |
|---|---|---|---|
| พักบิล สำเร็จ | `AppTheme.primary` (`#E57200`) | 240 | default |
| สแกนไม่พบสินค้า | `AppTheme.error` (`#C62828`) | 320 | 1,800ms |
| สแกนสำเร็จ | `AppTheme.success` (`#2E7D32`) | 300 | 900ms |
| ราคา fallback | `Colors.orange.shade700` | 380 | 3,000ms |

- ทุกตัว: `SnackBarBehavior.floating`, `borderRadius 8`

---

## ปุ่มใน Dialog

| ประเภท | Light | Dark |
|---|---|---|
| `FilledButton` (หลัก) | BG: `#E57200`, text: white | BG: `#FF9D45`, text: `#4A1900` |
| `TextButton` | text: `#E57200` | text: `#FF9D45` |
| `ElevatedButton` | BG: `#E57200`, text: white | BG: `#FF9D45`, text: `#4A1900` |

- border radius ปุ่ม: `8px`
- Dialog shape: `borderRadius 16`
- Dialog icon (Logout): `Colors.orange`
- Dialog icon (อัพเดทราคา): `AppTheme.warning` (`#F9A825`)

### Cashier Badge (ใน AppBar)

- BG: `AppTheme.primary @ 20%`
- Border: `AppTheme.primary @ 50%`
- ข้อความ: `AppTheme.primaryLight` (`#FF9D45`), `fontSize 11, w600`
- Radius: `6`

---

## Empty State

- วงกลม icon: BG `AppTheme.surface`, border `AppTheme.border`, ขนาด `80×80`
- ไอคอน: `Icons.inventory_2_outlined, size 38, Colors.grey`
- ข้อความหลัก: `fontSize 15, w500`
- ข้อความรอง: `fontSize 13, AppTheme.textSub` (`#757575`)
- ปุ่มรีเฟรช: `ElevatedButton.icon`

## Error State

- ไอคอน: `Icons.error_outline, size 64, AppTheme.error` (`#C62828`)
- ปุ่มลองใหม่: `ElevatedButton.icon`

---

## Layout ตามขนาดหน้าจอ

| หน้าจอ | เงื่อนไข | Layout |
|---|---|---|
| **Mobile** | `context.isMobile` | redirect ไป `MobileOrderPage` |
| **Tablet** | `context.isTablet` | AppBar toolbar สูง `40px`, chips อยู่ใน `bottom` bar (`40px`) |
| **Desktop** | ไม่ใช่ทั้งสอง | AppBar toolbar ปกติ, chips อยู่ใน toolbar row โดยตรง |

### Desktop Body

```
┌─────────────────────────────────┬──────────────────────┐
│        Product Grid (60%)       │   Cart Panel (40%)   │
│                                 │                      │
└─────────────────────────────────┴──────────────────────┘
```

- Divider ระหว่าง Grid/Cart: `AppTheme.border`, ความหนา `1px`

### Tablet — AppBar Modes

| สถานะ | toolbarHeight | bottom |
|---|---|---|
| Normal (ไม่ใช่ cashier) | `0` (ซ่อน) | chips `40px` |
| Cashier Mode | `40px` | chips `40px` |

---

## Dark Mode — Surface Colors

| Token | ค่าสี | ใช้ที่ไหน |
|---|---|---|
| `AppTheme.darkBg` | `#121212` | Scaffold background |
| `AppTheme.darkCard` | `#1E1E1E` | Card, Dialog |
| `AppTheme.darkElement` | `#2A2A2A` | Input fill, Popup |
| `AppTheme.darkTopBar` | `#1E1E1E` | Search toolbar |
| dark border | `#333333` | border ทุกที่ใน dark mode |
| dark text | `#E0E0E0` | ข้อความหลัก |
| dark subtext | `#9E9E9E` | ข้อความรอง |
