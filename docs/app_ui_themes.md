# App UI Themes

เอกสารนี้ใช้รวบรวมแนวทาง Theme UI ของแอพ เพื่อใช้สร้างระบบธีมใหม่ทีละส่วน
ข้อมูลในเอกสารนี้จะถูกเติมเพิ่มจากข้อมูลที่ส่งมาเป็นรอบ ๆ

## สถานะเอกสาร

- เวอร์ชันเริ่มต้น: บันทึกรูปแบบ Card จากหน้า `รายการสินค้า`
- แหล่งอ้างอิงปัจจุบัน: `lib/features/products/presentation/pages/product_list_page.dart`
- หมายเหตุ: ค่า `AppTheme.*` เดิมถูกใช้เป็นชื่ออ้างอิงในโค้ดเดิม ให้แปลงเป็น design token ของธีมใหม่ภายหลัง

## Responsive Theme Breakpoints

อ้างอิงจาก `lib/shared/utils/responsive_utils.dart` และใช้เป็นฐานกลางของ Theme UI ทุกหน้า

| Device | Width | การใช้งาน |
| --- | --- | --- |
| Mobile XS | `< 480` | มือถือเล็ก |
| Mobile | `< 768` | มือถือทั่วไป |
| Tablet | `768 - 1023` | tablet portrait / หน้าจอกลาง |
| Desktop | `1024 - 1599` | tablet landscape / laptop / desktop |
| Large Desktop | `>= 1600` | desktop ใหญ่ |

### Responsive Defaults

| Token | Mobile | Tablet | Desktop |
| --- | --- | --- | --- |
| `page.padding` | `12` | `16` | `24` |
| `card.padding` | `12` | `16` | `16` |
| `content.maxWidth` | `double.infinity` | `800` | `1200` |
| `title.fontSize` | `16` | `18` | `20` |
| `body.fontSize` | `12` | `14` | `14` |
| `icon.size` | `36` | `44` | `48` |
| `sidebar.mode` | Drawer overlay | Drawer overlay | Permanent sidebar |
| `product.defaultView` | Card View | Table/Card ได้ | Table View |

### Product Page Responsive Layout

| Area | Mobile | Tablet | Desktop |
| --- | --- | --- | --- |
| title bar | compact 2 rows | compact หรือ wide ตามพื้นที่ | wide 1 row |
| title font | `15` ใน Product TopBar | `15-16` | `16` |
| search | เต็มพื้นที่แถวที่ 2 | จำกัดตามพื้นที่ | max width `200` |
| filter/dropdown | อยู่ขวาของ search | อยู่กับ search | อยู่ในแถว title |
| summary bar | horizontal scroll | horizontal scroll เมื่อไม่พอ | ซ้าย/ขวาแบบ space-between |
| content panel margin | ลดได้เป็น `12` รอบ panel | `16` | `16` ตามหน้า Product เดิม |
| list item | touch-friendly card | card/table hybrid | table หรือ card |
| action buttons | icon compact | icon compact/label ได้ | icon + label หรือ compact ตามพื้นที่ |

## Page UI Placement

กติกานี้ใช้กำหนดตำแหน่งการวาง UI ระดับหน้า เพื่อให้ทุกหน้าในแอพมีโครงสร้างเหมือนกันและต่อยอดจาก component specs ด้านล่างได้ตรงกัน

### Page Layout Order

ลำดับการวางจากบนลงล่าง

| ลำดับ | Area | ตำแหน่ง | Alignment |
| --- | --- | --- | --- |
| 1 | Page title / top bar | บนสุดของพื้นที่ content | title/icon ชิดซ้าย, actions ชิดขวา |
| 2 | Summary / status bar | ใต้ title bar | metrics ซ้าย, financial/actions ขวา |
| 3 | Filter/search row | อยู่ใน title bar หรือใต้ title ตามขนาดหน้าจอ | search ซ้าย/เต็มพื้นที่, filters ต่อทางขวา |
| 4 | Content panel | พื้นที่กลางหลัก | กินพื้นที่ที่เหลือด้วย `Expanded` |
| 5 | ListView / TableView | ภายใน content panel | list item เรียงบนลงล่าง |
| 6 | Footer / pagination | ใต้ content panel | count ซ้าย, page nav กลาง, export/actions ขวา |

### Page Shell

| คุณสมบัติ | ค่า |
| --- | --- |
| root layout | `Column` |
| background | `productList.scaffoldBg` หรือ page scaffold token |
| top bar | fixed height ตาม content ไม่ scroll |
| summary bar | fixed height ตาม content ไม่ scroll |
| content area | `Expanded` |
| footer | fixed height ตาม content ไม่ scroll |
| scroll area | เฉพาะ ListView/TableView ภายใน content panel |

### Horizontal Placement Rules

| UI | ซ้าย | กึ่งกลาง | ขวา |
| --- | --- | --- | --- |
| Title bar desktop | back + icon + title | เว้นด้วย `Spacer` | search, filters, actions, add, badge |
| Title bar mobile/tablet | back + icon + title | - | compact actions |
| Search/filter mobile | search กินพื้นที่ | - | dropdown/filter |
| Summary bar | count chips | flexible space | value stats |
| Content panel | margin ซ้าย `16` desktop / `12` mobile | fills width | margin ขวา `16` desktop / `12` mobile |
| List item | avatar + content | content expands | action buttons |
| Footer wide | item count | page navigation | PDF/export |
| Footer narrow | item count | page navigation แถวล่างชิดซ้าย | PDF/export แถวบน |

### Vertical Placement Rules

| UI | ระยะ/ตำแหน่ง |
| --- | --- |
| title bar | บนสุด ไม่มี margin ด้านบน |
| summary bar | ต่อจาก title bar ทันที |
| content panel | margin top `0`, margin left/right/bottom ตาม panel spec |
| ListView padding | `12` รอบด้านภายใน panel |
| footer | ต่อจาก content list/table และใช้ radius เฉพาะมุมล่าง |
| pagination row narrow | แถวบน leading/trailing, แถวล่าง page nav, gap `6` |

### Mobile Placement

| Area | Placement |
| --- | --- |
| title bar | compact 2 rows: row 1 title/actions, row 2 search/filter |
| page title | ชิดซ้ายและ ellipsis ได้ |
| search | `Expanded` เต็มพื้นที่แถวที่ 2 |
| summary | horizontal scroll, ไม่ wrap หลายบรรทัด |
| content panel | margin รอบนอก `12` หรือค่าที่ใกล้เคียง |
| list item | Card View เป็นค่าเริ่มต้น |
| trailing actions | icon only ชิดขวา |
| footer | leading + PDF แถวบน, page nav แถวล่าง |

### Tablet Placement

| Area | Placement |
| --- | --- |
| title bar | compact หรือ wide ตามพื้นที่จริง |
| search/filter | อยู่แถว title ถ้าพอ ไม่พอให้แยกเป็นแถวที่ 2 |
| summary | ใช้ space-between เมื่อพอ และ fallback เป็น horizontal scroll |
| content panel | margin `16`, content max width ใช้ได้ถึง `800` เมื่อเป็นหน้า focused |
| list/table | ใช้ Card View หรือ Table View ได้ตาม density |
| footer | wide layout ถ้าพอ, narrow layout เมื่อมี trailing แล้วพื้นที่น้อย |

### Desktop Placement

| Area | Placement |
| --- | --- |
| title bar | wide 1 row |
| title group | back/icon/title ชิดซ้าย |
| controls | search/filter/actions/add/badge ชิดขวา |
| summary | count chips ชิดซ้าย, value stats ชิดขวา |
| content panel | margin `16`, กินพื้นที่ด้วย `Expanded` |
| list/table | Table View เป็นค่าเริ่มต้น แต่ Card View ยังใช้ placement เดียวกัน |
| footer | Stack alignment: leading ซ้าย, page nav กลาง, PDF ขวา |

### Placement Tokens

| Token ใหม่ | ค่าอ้างอิง |
| --- | --- |
| `page.layout.axis` | vertical |
| `page.title.position` | top |
| `page.summary.position` | belowTitle |
| `page.content.position` | middleExpanded |
| `page.footer.position` | bottom |
| `page.content.margin.mobile` | `12` |
| `page.content.margin.tablet` | `16` |
| `page.content.margin.desktop` | `16` |
| `page.section.gap` | `0` ระหว่าง title/summary/content |
| `page.footer.narrowBreakpoint` | `720` เมื่อมี trailing |

## Sub Page Form Action Bar

ใช้กับหน้าย่อยแบบฟอร์ม เช่น `เพิ่มลูกค้า` / `แก้ไขลูกค้า` ที่มีปุ่ม `บันทึก`, `เพิ่ม`, และ `ยกเลิก` อยู่ท้ายหน้าจอ

### Customer Form Reference

อ้างอิงจาก `lib/features/customers/presentation/pages/customer_form_page.dart`

| State | Primary label | Primary icon |
| --- | --- | --- |
| create | `เพิ่มลูกค้า` | `Icons.save_outlined` |
| edit | `บันทึก` | `Icons.save_outlined` |
| loading | label เดิม | `CircularProgressIndicator` |
| cancel | `ยกเลิก` | ไม่มี icon |

### Form Page Layout

| Area | ตำแหน่ง | Behavior |
| --- | --- | --- |
| Form header | บนสุด | icon + title ซ้าย, close button ขวาเมื่อเป็น dialog desktop |
| Form body | กลาง | `Expanded` + `SingleChildScrollView` |
| Bottom action bar | ล่างสุด | fixed ไม่ scroll ไปกับ form body |

### Form Header

| คุณสมบัติ | ค่า |
| --- | --- |
| background light | `Colors.white` |
| background dark | `AppTheme.darkTopBar` |
| padding | horizontal `20`, vertical `14` |
| title create | `เพิ่มลูกค้า` |
| title edit | `แก้ไขลูกค้า` |
| title size | `18` |
| title weight | `bold` |
| title color light | `Color(0xFF1A1A1A)` |
| title color dark | `Colors.white` |
| icon | `Icons.person_add` |
| icon container padding | `8` |
| icon container radius | `8` |
| icon container bg | `AppTheme.primaryLight` |
| icon color | `AppTheme.primary` |
| icon size | `20` |
| icon to title gap | `12` |
| mobile home/back gap | `10` |
| close icon size | `20` |

### Bottom Action Bar Placement

| คุณสมบัติ | ค่า |
| --- | --- |
| position | ล่างสุดของหน้า/ฟอร์ม |
| background light | `Colors.white` |
| background dark | `AppTheme.darkTopBar` |
| padding | horizontal `20`, vertical `14` |
| breakpoint stacked | width `< 560` |
| wide alignment | ชิดขวา |
| stacked alignment | เต็มความกว้าง เรียงบนลงล่าง |
| scroll behavior | action bar fixed, form body scroll แยก |

### Wide Action Layout

ใช้เมื่อพื้นที่กว้าง `>= 560`

| ลำดับ | Button | Alignment | Gap |
| --- | --- | --- | --- |
| 1 | `ยกเลิก` | ชิดขวา | - |
| 2 | `บันทึก` / `เพิ่มลูกค้า` | ต่อจากปุ่มยกเลิก | `12` |

โครงสร้าง layout: `Row(mainAxisAlignment: MainAxisAlignment.end)`

### Stacked Action Layout

ใช้เมื่อพื้นที่แคบ `< 560`

| ลำดับ | Button | Width | Gap |
| --- | --- | --- | --- |
| 1 | `บันทึก` / `เพิ่มลูกค้า` | เต็มความกว้าง | - |
| 2 | `ยกเลิก` | เต็มความกว้าง | `10` |

โครงสร้าง layout: `Column(crossAxisAlignment: CrossAxisAlignment.stretch)`

### Primary Save / Add Button

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `ElevatedButton.icon` |
| background | `AppTheme.primary` |
| foreground | `Colors.white` |
| padding | horizontal `24`, vertical `12` |
| radius | `8` |
| elevation | `0` |
| icon | `Icons.save_outlined` |
| icon size | `18` |
| text size | `14` |
| loading indicator size | `16 x 16` |
| loading stroke | `2` |
| loading color | `Colors.white` |
| disabled state | `onPressed: null` ระหว่าง loading |

### Secondary Cancel Button

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `OutlinedButton` |
| label | `ยกเลิก` |
| padding | horizontal `24`, vertical `12` |
| radius | `8` |
| border light | `AppTheme.border` |
| border dark | ควรใช้ `Colors.white12` หรือ `Color(0xFF333333)` |
| text color light | `AppTheme.textSub` |
| text color dark | `Color(0xFF9E9E9E)` |
| disabled state | `onPressed: null` ระหว่าง loading |

### Form Action Bar Responsive Rules

| Device | Layout |
| --- | --- |
| Mobile | stacked, primary button อยู่บน, cancel อยู่ล่าง, ทั้งคู่เต็มความกว้าง |
| Tablet | wide ถ้าพื้นที่ `>= 560`, stacked ถ้า dialog แคบ |
| Desktop | wide, ปุ่มทั้งหมดชิดขวา |

### Form Action Tokens

| Token ใหม่ | ค่าอ้างอิง |
| --- | --- |
| `formAction.position` | bottomFixed |
| `formAction.paddingX` | `20` |
| `formAction.paddingY` | `14` |
| `formAction.stackedBreakpoint` | `560` |
| `formAction.button.paddingX` | `24` |
| `formAction.button.paddingY` | `12` |
| `formAction.button.radius` | `8` |
| `formAction.primary.iconSize` | `18` |
| `formAction.primary.textSize` | `14` |
| `formAction.loading.size` | `16` |
| `formAction.wide.gap` | `12` |
| `formAction.stacked.gap` | `10` |

## Product List Card

### โครงสร้างหลัก

หน้า `รายการสินค้า` มี Card อยู่ 2 ชั้นหลัก

1. Content panel ครอบรายการทั้งหมด
2. Product item card สำหรับสินค้าแต่ละรายการ

### Content Panel

ใช้เป็นกล่องครอบ Table View หรือ Card View ของรายการสินค้า

| คุณสมบัติ | ค่า |
| --- | --- |
| margin | `EdgeInsets.fromLTRB(16, 0, 16, 16)` |
| background light | `Colors.white` |
| background dark | `Color(0xFF2C2C2C)` |
| border radius | `12` |
| border light | `AppTheme.border` |
| border dark | `Color(0xFF333333)` |
| shadow light | `AppTheme.navy` alpha `0.04`, blur `16`, offset `(0, 6)` |
| shadow dark | ไม่มี shadow |

### Product Item Card

ใช้ใน Card View สำหรับสินค้าแต่ละรายการ

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `Card` |
| elevation | `0` |
| margin | `EdgeInsets.zero` |
| background light | `Colors.white` |
| background dark | `Color(0xFF2C2C2C)` |
| border radius | `10` |
| border | ใช้สี `ProductList.border` |
| inner padding | `EdgeInsets.all(12)` |
| layout | `Row` |
| item separator | `Divider(height: 1, color: ProductList.border)` |
| list padding | `EdgeInsets.all(12)` |

### Product Card Layout

ลำดับ element ภายใน card

1. Avatar สินค้า
2. ระยะห่าง `12`
3. กลุ่มข้อมูลสินค้าแบบ `Expanded`
4. ปุ่ม action แนวตั้ง

### Avatar

| คุณสมบัติ | ค่า |
| --- | --- |
| shape | `CircleAvatar` |
| radius | `20` |
| text | ตัวอักษรแรกของชื่อสินค้า หรือ `?` |
| text color | `Colors.white` |
| text size | `14` |
| text weight | `FontWeight.bold` |

Palette สำหรับ avatar เลือกจากชื่อสินค้า

| Token เดิม | ความหมาย |
| --- | --- |
| `AppTheme.primary` | สีหลัก |
| `AppTheme.info` | สีข้อมูล |
| `AppTheme.success` | สีสำเร็จ |
| `AppTheme.warning` | สีเตือน |
| `AppTheme.purpleColor` | สีเสริม |
| `AppTheme.tealColor` | สีเสริม |

### Non Stock Control Badge

แสดงบน avatar เมื่อสินค้าไม่ได้ควบคุมสต๊อก

| คุณสมบัติ | ค่า |
| --- | --- |
| position | right `-2`, bottom `-2` |
| size | `14 x 14` |
| shape | circle |
| background | `AppTheme.textSub` |
| border | `Colors.white`, width `1.5` |
| icon | `Icons.remove_circle_outline` |
| icon size | `8` |
| icon color | `Colors.white` |

## Dated Action Card UI

ใช้กับหน้าที่ผู้ใช้คลิกเข้าไปดูรายการย่อย แล้วข้อมูลถูกแสดงเป็นการ์ดหรือแถวรายการตามวันที่ เช่น ประวัติการขาย, ประวัติสต๊อก, รายการเอกสารรายวัน หรือหน้าที่มีปุ่มดำเนินการต่อรายการ

### Use Case

| กรณี | รูปแบบ |
| --- | --- |
| คลิกจากรายการหลักเข้าไปดูรายละเอียด | แสดงรายการย่อยเรียงตามวันที่ |
| รายการมีวันที่/เวลาเป็นข้อมูลหลัก | วางวันที่ไว้ช่วงต้นของ card/row |
| รายการมีสถานะ | ใช้ status icon หรือ status badge |
| รายการมี action | วางปุ่มดำเนินการชิดขวาหรือท้าย card |
| รายการมีมูลค่า/ยอดเงิน | วางชิดขวาใน table row หรืออยู่ใน content flow ของ card |

### Dated Action Card Structure

| Zone | ตำแหน่ง | Content |
| --- | --- | --- |
| Leading status | ซ้ายสุด | avatar/icon แสดงสถานะของรายการ |
| Date/time | ถัดจาก leading | วันที่หรือวันที่-เวลา |
| Primary info | กลางซ้าย | เลขเอกสาร, ชื่อรายการ, ชื่อลูกค้า |
| Secondary info | ใต้/ถัดจาก primary | metadata เช่น ประเภทบริการ, วิธีชำระ, note |
| Amount/value | กลางขวาหรือใน content | ยอดเงินหรือค่าหลักของรายการ |
| Status badge | ก่อน action หรือในแถวสถานะ | สถานะรายการ |
| Actions | ขวาสุด | ปุ่มดูรายละเอียด, แก้ไข, ยกเลิก, ส่งออก |

### Dated Action Card Container

| คุณสมบัติ | ค่า |
| --- | --- |
| background light | `Colors.white` |
| background dark | `Color(0xFF2C2C2C)` |
| hover light | `AppTheme.primaryLight` |
| hover dark | `AppTheme.primaryLight` alpha `0.15` |
| border | `ProductList.border` หรือ `dark.border` |
| row padding | horizontal `16`, vertical `10` |
| card padding mobile | `12` |
| transition | `AnimatedContainer`, `120ms` |
| separator | `Divider(height: 1, color: border)` |
| tap target | ทั้ง card/row กดเพื่อเปิดรายละเอียดได้ |

### Date-Based Layout

| Element | Alignment | Typography |
| --- | --- | --- |
| วันที่-เวลา | ชิดซ้าย | `fontSize 12`, color `subtext` |
| เลขเอกสาร/เลขรายการ | ชิดซ้าย | `fontSize 13`, `w600`, color `text` |
| ชื่อ/ลูกค้า | ชิดซ้าย | `fontSize 13`, color `text` |
| metadata | ชิดซ้าย | `fontSize 11-12`, color `subtext` |
| ยอดเงิน | ชิดขวาใน table, ชิดซ้ายใน mobile card ได้ | `fontSize 13`, `w700`, color `amountText` |
| สถานะ | กึ่งกลางใน column/table cell หรือท้าย content | badge style |
| action icons | กึ่งกลางในปุ่ม | icon size `15-16` |

### Status Leading Icon

ใช้แสดงสถานะรวมของรายการก่อนอ่านข้อความ

| Status | Background | Icon | Icon color |
| --- | --- | --- | --- |
| completed/success | `AppTheme.successContainer` | `Icons.check` | `AppTheme.success` |
| cancelled/error | `AppTheme.errorContainer` | `Icons.close` | `AppTheme.error` |
| pending/waiting | `Color(0xFFFFF8E1)` | `Icons.hourglass_empty` | `AppTheme.warning` |

| คุณสมบัติ | ค่า |
| --- | --- |
| shape | `CircleAvatar` |
| radius | `14` |
| cell width desktop/table | `40` |
| icon size | `14` |

### Action Buttons In Card

ปุ่มดำเนินการใน card ใช้แบบ icon-only เพื่อไม่ให้แย่งพื้นที่ข้อมูลหลัก

| Action | Icon | Color | Tooltip |
| --- | --- | --- | --- |
| ดูรายละเอียด | `Icons.open_in_new` | `AppTheme.primary` | `ดูรายละเอียด` |
| แก้ไข | `Icons.edit_outlined` | `AppTheme.info` | `แก้ไข` |
| ยกเลิก | `Icons.cancel_outlined` | `AppTheme.error` | `ยกเลิกออเดอร์` หรือ label ตาม domain |
| ลบ | `Icons.delete_outline` | `AppTheme.error` | `ลบ` |
| PDF/เอกสาร | `Icons.picture_as_pdf_outlined` | `Color(0xFFE8622A)` | `แสดง PDF` |

### Action Button Style

| คุณสมบัติ | ค่า |
| --- | --- |
| wrapper | `Tooltip` + `InkWell` |
| tooltip wait | `600ms` สำหรับ row/table, `400ms` สำหรับ card compact ได้ |
| padding | `EdgeInsets.all(6)` |
| radius | `8` |
| background | action color alpha `0.08` |
| border | action color alpha `0.18` |
| icon size | `15` |
| action gap | `6` |
| layout desktop/table | `Row(mainAxisAlignment: MainAxisAlignment.center)` |
| layout mobile/card | trailing `Column` หรือ `Row` ท้าย card ตามพื้นที่ |

### Payment / Type Badge

ใช้กับรายการที่มีประเภทชำระเงินหรือประเภทเอกสาร

| Type | Text | Text color | Background |
| --- | --- | --- | --- |
| cash | `เงินสด` | `AppTheme.success` | `AppTheme.successContainer` |
| card | `บัตร` | `AppTheme.info` | `AppTheme.infoContainer` |
| transfer | `โอน` | `Color(0xFF6A1B9A)` | `Color(0xFFF3E5F5)` |
| default | raw value | `AppTheme.textSub` | neutral chip bg |

| คุณสมบัติ | ค่า |
| --- | --- |
| padding | horizontal `8`, vertical `3` |
| radius | `12` |
| border | badge color alpha `0.18` |
| text size | `11` |
| text weight | `w600` |

### Dated Status Badge

| Status | Label | Color | Background |
| --- | --- | --- | --- |
| completed | `สำเร็จ` | `AppTheme.success` | `AppTheme.successContainer` |
| pending | `รอดำเนินการ` | `AppTheme.warning` | `Color(0xFFFFF8E1)` |
| cancelled | `ยกเลิก` | `AppTheme.error` | `AppTheme.errorContainer` |
| default | raw value | `AppTheme.textSub` | neutral chip bg |

| คุณสมบัติ | ค่า |
| --- | --- |
| padding | horizontal `6-8`, vertical `3-4` |
| radius | `12` |
| dot size | `5 x 5` |
| dot to text gap | `4` |
| border | status color alpha `0.16` |
| text size | `11` |
| text weight | `w600` |

### Dated Action Card Dark Mode

| Element | Dark value |
| --- | --- |
| card/row background | `Color(0xFF2C2C2C)` |
| hover background | `AppTheme.primaryLight` alpha `0.15` |
| border/divider | `Color(0xFF333333)` |
| primary text | `Color(0xFFE0E0E0)` |
| secondary text | `Color(0xFF9E9E9E)` |
| amount text | `AppTheme.primaryLight` |
| cancelled amount | `Color(0xFFB0B0B0)`, line-through |
| neutral chip bg | `Color(0xFF2A2A2A)` |
| action bg | action color alpha `0.08` |
| action border | action color alpha `0.18` |

### Dated Action Card Responsive Layout

| Device | Layout |
| --- | --- |
| Mobile | ใช้ card แนวตั้ง: date/title ด้านบน, metadata ต่อมา, amount/status ต่อมา, actions ชิดขวาล่าง |
| Tablet | ใช้ card หรือ row hybrid: leading/status ซ้าย, content กลาง, actions ขวา |
| Desktop | ใช้ row/table: date, document no, customer, type, amount, status, actions เป็น column ชัดเจน |

### Dated Action Card Placement Rules

| Content | Placement |
| --- | --- |
| วันที่ | อยู่ก่อนเลขเอกสารเสมอ หรือเป็น column แรกหลัง leading |
| เลขเอกสาร | อยู่ใกล้วันที่และใช้ weight หนากว่า metadata |
| ชื่อลูกค้า/ชื่อรายการ | อยู่ถัดจากเลขเอกสารหรือใต้เลขเอกสารใน mobile |
| ยอดเงิน | ชิดขวาใน desktop/table, อยู่ใต้ข้อมูลหลักใน mobile |
| สถานะ | อยู่ก่อน actions หรือใกล้ยอดเงิน |
| ปุ่มดำเนินการ | อยู่ท้ายสุดของ card/row และไม่ปะปนกับข้อมูลอ่าน |

### Typography

| Element | ขนาด | Weight | สี |
| --- | --- | --- | --- |
| ชื่อสินค้า | `13` | `w600` | `ProductList.text` |
| รหัสสินค้า | `11` | default | `ProductList.subtext` |
| Barcode | `11` | default | `ProductList.subtext` |
| ราคา | `12` | `w700` | `ProductList.amountText` |
| หน่วย | `11` | default | `ProductList.subtext` |
| ต้นทุน | `11` | default | `ProductList.subtext` |
| สต๊อก/มูลค่า | `11` | default | `ProductList.subtext` |

ระยะห่างสำคัญ

| จุด | ค่า |
| --- | --- |
| Avatar ถึง info | `12` |
| ชื่อสินค้าถึง status badge | `8` |
| ชื่อแถวแรกถึงรหัสสินค้า | `3` |
| ราคาถึงหน่วย | `6` |
| หน่วยถึงต้นทุน | `8` |
| ราคาแถวถึงสต๊อก | `2` |

### Status Badge

ใช้แสดงสถานะ `ใช้งาน` / `ปิดใช้`

| คุณสมบัติ | ค่า |
| --- | --- |
| padding | horizontal `8`, vertical `2` |
| radius | `10` |
| active background | `AppTheme.successContainer` |
| inactive background | `AppTheme.errorContainer` |
| active border | `AppTheme.success` alpha `0.18` |
| inactive border | `AppTheme.error` alpha `0.18` |
| dot size | `5 x 5` |
| active dot | `Color(0xFF4CAF50)` |
| inactive dot | `Color(0xFFF44336)` |
| text size | `10` |
| text weight | `w600` |
| active text | `Color(0xFF2E7D32)` |
| inactive text | `Color(0xFFC62828)` |

### Action Icon Button

ใช้สำหรับปุ่มแก้ไขและลบใน Product Card

| คุณสมบัติ | ค่า |
| --- | --- |
| wrapper | `Tooltip` + `InkWell` |
| tooltip wait | `400 ms` |
| size | `32 x 32` |
| alignment | center |
| radius | `8` |
| background | action color alpha `0.08` |
| border | action color alpha `0.18` |
| icon size | `16` |
| spacing between buttons | `4` |

Action colors

| Action | Icon | สี |
| --- | --- | --- |
| แก้ไข | `Icons.edit_outlined` | `AppTheme.info` |
| ลบ | `Icons.delete_outline` | `AppTheme.error` |

## Product Page Title UI

ใช้เป็น title area ของหน้า `รายการสินค้า` ภายใน `_ProductListTopBar`

### Title Bar Container

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `Container` |
| background | `ProductList.topBarBg` |
| background light | `AppTheme.navy` |
| background dark | `AppTheme.navyDark` |
| padding | horizontal `16`, vertical `12` |
| responsive breakpoint | `960` |
| wide layout | row เดียว |
| compact layout | title row + search/filter row |

### Wide Title Layout

ใช้เมื่อความกว้างหน้าจอ `>= 960`

ลำดับ element

1. Back button ถ้า `Navigator.canPop`
2. ระยะห่าง `10`
3. Page icon
4. ระยะห่าง `10`
5. Title text `รายการสินค้า`
6. `Spacer`
7. Search field
8. Warehouse dropdown
9. Toggle/action buttons
10. Primary add button
11. Module badge `Products`

| Element | ค่า |
| --- | --- |
| title text | `รายการสินค้า` |
| title font size | `16` |
| title weight | `w600` |
| title color | `Colors.white` |
| search max width | `200` |
| spacing search ถึง dropdown | `8` |
| spacing ระหว่าง action buttons | `6` |
| spacing add button ถึง module badge | `8` |

### Title Search Placement Rule

ใช้เป็นกติกากลางสำหรับหน้าที่ต้องวางช่องค้นหาบน title bar ให้เหมือนหน้า `รายการสินค้า` เช่น `ภาพรวมการจอง`

| Rule | ค่า |
| --- | --- |
| ตำแหน่งหลัก | อยู่ฝั่งขวาของ title bar หลัง `Spacer()` |
| ลำดับ desktop/wide | page icon, title, `Spacer`, search field, filters/actions, primary action, module badge |
| ลำดับเมื่อมี refresh | page icon, title, `Spacer`, search field, refresh/action buttons |
| ความกว้าง search | `maxWidth: 200` |
| spacing title ถึง search | ใช้ `Spacer()` ไม่ใช้ fixed gap เพื่อให้ search ชิดกลุ่ม action ด้านขวา |
| spacing search ถึง action ถัดไป | `8` |
| การหดบนพื้นที่แคบ | ลด max width หรือย้าย search ลงแถวที่ 2 ตาม compact layout |
| ไม่ควรทำ | วาง search ต่อจาก title ทันทีโดยไม่มี `Spacer()` เพราะตำแหน่งจะไม่ตรง pattern หน้า `รายการสินค้า` |

ตัวอย่างโครงสำหรับ title bar แบบแถวเดียว

```dart
Row(
  children: [
    pageIcon,
    const SizedBox(width: 10),
    title,
    const Spacer(),
    ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: searchField,
    ),
    const SizedBox(width: 8),
    refreshOrActionButton,
  ],
)
```

### Compact Title Layout

ใช้เมื่อความกว้างหน้าจอ `< 960`

แถวที่ 1: back button, page icon, title, action icons  
แถวที่ 2: search field และ warehouse dropdown

| Element | ค่า |
| --- | --- |
| title wrapper | `Expanded` |
| title text | `รายการสินค้า` |
| title font size | `15` |
| title weight | `w600` |
| title color | `Colors.white` |
| title overflow | `TextOverflow.ellipsis` |
| row spacing title to controls | action spacing `4` |
| spacing ระหว่าง row 1 และ row 2 | `10` |
| search field | `Expanded` |
| spacing search ถึง dropdown | `8` |

### Page Icon

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `Container` |
| padding | `EdgeInsets.all(7)` |
| radius | `8` |
| background | `AppTheme.primary` alpha `0.18` |
| border | `AppTheme.primary` alpha `0.28` |
| icon | `Icons.inventory_2_outlined` |
| icon size | `18` |
| icon color | `AppTheme.primaryLight` |

### Back Button

ใช้เฉพาะเมื่อหน้า route สามารถย้อนกลับได้

| คุณสมบัติ | ค่า |
| --- | --- |
| desktop/tablet widget | `InkWell` + `Container` |
| mobile widget | `buildMobileHomeCompactButton(context)` |
| padding | `EdgeInsets.all(7)` |
| radius | `8` |
| background | `ProductList.navButtonBg` |
| border | `ProductList.navButtonBorder` |
| icon | `Icons.arrow_back` |
| icon size | `17` |
| icon color | `Colors.white70` |

### Module Badge

แสดงคำว่า `Products` ทางขวาสุดใน wide layout

| คุณสมบัติ | ค่า |
| --- | --- |
| text | `Products` |
| padding | horizontal `10`, vertical `5` |
| radius | `6` |
| background | `AppTheme.primary` alpha `0.2` |
| border | `AppTheme.primary` alpha `0.5` |
| text size | `11` |
| text weight | `w600` |
| text color | `AppTheme.primaryLight` |

### Title Bar Actions

| Action | Icon | Tooltip | สี/สถานะ |
| --- | --- | --- | --- |
| active only toggle | `Icons.check_circle_outline` | `แสดงทั้งหมด` / `เฉพาะที่ใช้งาน` | active ใช้ `AppTheme.success` |
| table/card toggle | `Icons.view_agenda_outlined` / `Icons.table_rows_outlined` | `Card View` / `Table View` | inactive ใช้ nav button style |
| refresh | `Icons.refresh` | `รีเฟรช` | nav button style |
| manage groups | `Icons.category_outlined` | ปุ่ม `หมวดสินค้า` หรือ icon compact | primary outline |
| manage modifiers | `Icons.tune` | ปุ่ม `Modifiers` หรือ icon compact | `Color(0xFF7B61FF)` |
| barcode | `Icons.qr_code_2_outlined` | ปุ่ม `สร้างบาร์โค้ด` หรือ icon compact | primary outline |
| add product | `Icons.add` | ปุ่ม `เพิ่มสินค้า` หรือ icon compact | primary filled |

### Title Bar Button Style

ใช้กับปุ่ม icon ใน title bar เช่น refresh/toggle/back

| คุณสมบัติ | ค่า |
| --- | --- |
| wrapper | `Tooltip` + `InkWell` |
| tooltip wait | `400 ms` |
| padding | `EdgeInsets.all(7)` |
| radius | `8` |
| default background | `ProductList.navButtonBg` |
| default border | `ProductList.navButtonBorder` |
| default icon color | `Colors.white70` |
| icon size | `17` |
| active background | active color alpha `0.1` |
| active border | active color |
| active icon color | active color |

### Product Title Theme Tokens

| Token ใหม่ | ค่าอ้างอิง |
| --- | --- |
| `pageTitle.background` | `ProductList.topBarBg` |
| `pageTitle.paddingX` | `16` |
| `pageTitle.paddingY` | `12` |
| `pageTitle.breakpoint` | `960` |
| `pageTitle.text.size.wide` | `16` |
| `pageTitle.text.size.compact` | `15` |
| `pageTitle.text.weight` | `w600` |
| `pageTitle.text.color` | `Colors.white` |
| `pageTitle.icon.size` | `18` |
| `pageTitle.icon.containerPadding` | `7` |
| `pageTitle.icon.radius` | `8` |
| `pageTitle.action.iconSize` | `17` |
| `pageTitle.action.padding` | `7` |
| `pageTitle.action.radius` | `8` |
| `pageTitle.moduleBadge.radius` | `6` |
| `pageTitle.moduleBadge.textSize` | `11` |

## Product ListView UI

ใช้เป็นรูปแบบมาตรฐานสำหรับหน้ารายการข้อมูลที่แสดงผลแบบ Card View โดยหน้า `รายการสินค้า` ใช้ `ListView.separated`

### ListView Structure

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `ListView.separated` |
| outer container | อยู่ภายใน Content Panel |
| padding | `EdgeInsets.all(12)` |
| item widget | Product Item Card |
| separator widget | `Divider` |
| separator height | `1` |
| separator color | `ProductList.border` |
| scroll direction | vertical |
| item count | จำนวนสินค้าที่ผ่าน filter และ pagination |

### List Item Layout

โครงสร้างแต่ละ item ควรเป็น row ที่อ่านข้อมูลเร็ว และมี action ชัดเจน

| Zone | รายละเอียด |
| --- | --- |
| Leading | Avatar หรือ icon ของรายการ |
| Content | ชื่อหลัก, metadata, ราคา/ตัวเลข, รายละเอียดรอง |
| Trailing | Action buttons |

Layout มาตรฐาน

1. `Row` เป็น layout หลัก
2. Leading ใช้ขนาดคงที่
3. Content ใช้ `Expanded`
4. Trailing ใช้ `Column(mainAxisSize: MainAxisSize.min)`
5. ข้อความหลักต้อง `overflow: TextOverflow.ellipsis`

### List Item Alignment

กติกาการจัดซ้าย/ขวา/กึ่งกลางใน ListView เพื่อให้ทุกหน้ารายการอ่านง่ายและวาง rhythm เหมือนกัน

| Zone | Horizontal alignment | Vertical alignment | เหตุผล |
| --- | --- | --- | --- |
| Leading avatar/icon | กึ่งกลางในพื้นที่ leading | กึ่งกลางแนวตั้งกับ item | เป็น anchor ของรายการ |
| Content column | ชิดซ้าย | กึ่งกลางตาม content height | อ่านข้อมูลหลักจากซ้ายไปขวา |
| Primary title | ชิดซ้าย | แถวบนสุดของ content | เป็นข้อมูลแรกที่สายตาควรเจอ |
| Status badge | ชิดขวาของ title row | กึ่งกลางกับ title baseline | ให้เห็นสถานะโดยไม่รบกวนชื่อ |
| Metadata lines | ชิดซ้าย | ต่อจาก title | ข้อมูลรองต้อง scan ง่าย |
| Price/value row | ชิดซ้าย | ใต้ metadata | ตัวเลขอยู่ใน flow เดียวกับข้อมูลสินค้า |
| Trailing actions | ชิดขวาสุดของ card | กึ่งกลางแนวตั้ง | action ต้องหาเจอเร็วและไม่ปนกับข้อมูล |
| Empty state | กึ่งกลางหน้า | กึ่งกลางหน้า | ใช้เมื่อไม่มีข้อมูล |
| Error state | กึ่งกลางหน้า | กึ่งกลางหน้า | ใช้เมื่อโหลดข้อมูลผิดพลาด |

### List Item Alignment Rules

| Element | Rule |
| --- | --- |
| item row | ใช้ `Row(crossAxisAlignment: CrossAxisAlignment.center)` เป็นค่าเริ่มต้น |
| content | ใช้ `Expanded` เพื่อกินพื้นที่กลางระหว่าง leading และ trailing |
| content column | ใช้ `Column(crossAxisAlignment: CrossAxisAlignment.start)` |
| title row | ใช้ `Row` ภายใน content เพื่อวางชื่อซ้ายและ badge ขวา |
| title text | ห่อด้วย `Expanded` และใช้ `TextOverflow.ellipsis` |
| status badge | อยู่หลัง title และมี `SizedBox(width: 8)` คั่น |
| trailing column | ใช้ `Column(mainAxisSize: MainAxisSize.min)` |
| action buttons | จัดกึ่งกลางใน trailing column และเรียงบนลงล่าง |
| divider | กินเต็มความกว้างของ ListView ตาม default separator |

### ListView Alignment By Device

| Device | Leading | Content | Trailing | Notes |
| --- | --- | --- | --- | --- |
| Mobile | กึ่งกลาง, ขนาดคงที่ | ชิดซ้าย, ให้พื้นที่มากที่สุด | ชิดขวา, icon only | หลีกเลี่ยงปุ่ม label ยาวใน list item |
| Tablet | กึ่งกลาง | ชิดซ้าย | ชิดขวา, icon หรือ compact label | อนุญาตให้บาง action มี label เมื่อพื้นที่พอ |
| Desktop | กึ่งกลาง | ชิดซ้าย | ชิดขวา | ถ้าเป็น table view ให้ตัวเลขชิดขวาได้ แต่ card view ยังคงชิดซ้ายใน content |

### Text And Number Alignment

| Content type | Alignment | ตัวอย่าง |
| --- | --- | --- |
| ชื่อรายการ | ชิดซ้าย | `p.productName` |
| รหัส/บาร์โค้ด | ชิดซ้าย | `รหัส: ...`, barcode |
| หน่วย/รายละเอียดรอง | ชิดซ้าย | `/ ชิ้น`, metadata |
| ราคาใน card | ชิดซ้าย | `฿120.00 / ชิ้น` |
| มูลค่ารวมใน card | ชิดซ้าย | `มูลค่า ฿...` |
| action icon | กึ่งกลางในปุ่ม | edit/delete |
| badge count | กึ่งกลางใน badge | summary count |
| empty/error message | กึ่งกลาง | empty state |

### ListView Spacing

| จุด | ค่า |
| --- | --- |
| ระยะขอบ list ถึง item | `12` |
| ระยะระหว่าง item | divider height `1` |
| ระยะภายใน item card | `12` |
| Leading ถึง content | `12` |
| Content ถึง status/action | `8` โดยประมาณ |
| ระยะระหว่าง action แนวตั้ง | `4` |

### List Item States

| State | UI |
| --- | --- |
| Default | card พื้นหลัง `ProductList.cardBg`, border `ProductList.border`, elevation `0` |
| Active item | status badge สี success |
| Inactive item | status badge สี error |
| No stock control | badge เล็กซ้อน avatar |
| Empty list | ใช้ empty state กลางหน้า |
| Error list | ใช้ error state กลางหน้า |

### Empty State

ใช้เมื่อไม่มีสินค้า หรือค้นหาแล้วไม่พบข้อมูล

| คุณสมบัติ | ค่า |
| --- | --- |
| layout | `Center` + `Column` |
| alignment | `MainAxisAlignment.center` |
| icon container size | `80 x 80` |
| icon container shape | circle |
| icon container background | `ProductList.emptyIconBg` |
| icon container border | `ProductList.border` |
| icon size | `38` |
| icon color | `ProductList.emptyIcon` |
| title size | `15` |
| title weight | `w500` |
| title color | `ProductList.text` |
| description size | `13` |
| description color | `ProductList.subtext` |
| icon to title spacing | `16` |
| title to description spacing | `6` |
| description to primary button spacing | `16` |

Empty icons

| กรณี | Icon |
| --- | --- |
| ไม่มีข้อมูลเริ่มต้น | `Icons.inventory_2_outlined` |
| ค้นหาไม่พบ | `Icons.search_off_outlined` |

### Error State

ใช้เมื่อโหลดรายการไม่สำเร็จ

| คุณสมบัติ | ค่า |
| --- | --- |
| layout | `Center` + `Column` |
| alignment | `MainAxisAlignment.center` |
| icon | `Icons.error_outline` |
| icon size | `64` |
| icon color | `AppTheme.error` |
| icon to message spacing | `16` |
| message color | `ProductList.text` |
| text align | center |
| message to retry button spacing | `16` |

### ListView Theme Tokens

ควรแยก token ของ ListView ออกจาก Card เพื่อใช้ซ้ำในหน้าอื่น

| Token ใหม่ | ค่าอ้างอิง |
| --- | --- |
| `listView.padding` | `12` |
| `listView.separator.height` | `1` |
| `listView.separator.color` | `ProductList.border` |
| `listItem.radius` | `10` |
| `listItem.padding` | `12` |
| `listItem.background` | `ProductList.cardBg` |
| `listItem.border` | `ProductList.border` |
| `listItem.elevation` | `0` |
| `listItem.leading.size` | `40` |
| `listItem.leading.radius` | `20` |
| `listItem.action.size` | `32` |
| `listItem.action.radius` | `8` |

## Product Page Footer / Pagination UI

ส่วนท้ายของหน้าจอใช้ `PaginationBar` อยู่ใต้ Content Panel และแยกการแสดงผลตามหน้า พร้อมรองรับปุ่มส่งออก PDF ทางขวา

### Footer Placement

| ลำดับ | Component | ตำแหน่ง |
| --- | --- | --- |
| 1 | Title Bar | บนสุดของหน้า |
| 2 | Summary Bar | ใต้ title |
| 3 | Content Panel / ListView | กลางหน้า |
| 4 | Footer / Pagination Bar | ล่างสุดของ content flow |

### Pagination Bar Structure

| Zone | Alignment | Default content |
| --- | --- | --- |
| Leading | ชิดซ้าย | ข้อความ `แสดง start-end จาก total รายการ` หรือ `ไม่มีรายการ` |
| Center | กึ่งกลาง | ปุ่มเลขหน้า, ปุ่มก่อนหน้า, ปุ่มถัดไป |
| Trailing | ชิดขวา | ปุ่ม PDF หรือ action อื่น |

### Pagination Bar Style

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `Container` |
| padding no trailing | horizontal `16`, vertical `8` |
| padding with trailing | horizontal `8`, vertical `8` |
| padding narrow | horizontal `8`, vertical `6` |
| background light | `AppTheme.headerBg` |
| background dark | `AppTheme.navyDark` |
| radius | bottomLeft `12`, bottomRight `12` |
| narrow breakpoint | เมื่อมี trailing และ width `< 720` |

### Pagination Responsive Layout

| Layout | เงื่อนไข | การวาง |
| --- | --- | --- |
| Wide | ไม่มี trailing หรือ width `>= 720` | ใช้ `Stack`: leading ซ้าย, center กึ่งกลาง, trailing ขวา |
| Narrow | มี trailing และ width `< 720` | แถวบน leading ซ้าย + trailing ขวา, แถวล่าง center ชิดซ้ายและ scroll แนวนอน |

### Pagination Count Text

| Element | ค่า |
| --- | --- |
| text no data | `ไม่มีรายการ` |
| text with data | `แสดง start-end จาก total รายการ` |
| font size | `12` |
| color light | `AppTheme.textSub` |
| color dark | `Colors.white60` |
| alignment wide | ซ้าย |
| alignment narrow | ซ้ายในแถวบน |

### Pagination Page Buttons

| Element | ค่า |
| --- | --- |
| nav icons | `Icons.chevron_left`, `Icons.chevron_right` |
| nav button size | `28 x 28` |
| page button min width | `28` |
| page button height | `28` |
| radius | `6` |
| horizontal gap | `4` รอบปุ่ม nav, `2` รอบ page button |
| icon size | `16` |
| page text size | `12` |
| active page weight | `w600` |

สีปุ่ม pagination

| State | Light | Dark |
| --- | --- | --- |
| nav/page enabled bg | `Colors.white` | `Colors.white` alpha `0.10` |
| nav/page enabled border | `AppTheme.border` | `Colors.white` alpha `0.22` |
| nav/page enabled text/icon | `Colors.black87` | `Colors.white` |
| disabled bg/border | transparent | transparent |
| disabled icon/text | `AppTheme.textSub` | `Colors.white24` |
| active bg/border | `AppTheme.primary` | `AppTheme.primary` |
| active text | `Colors.white` | `Colors.white` |
| ellipsis | `AppTheme.textSub` | `Colors.white38` |

## PDF Export Button UI

ใช้ `PdfReportButton` เป็น trailing action ใน Footer/Pagination Bar

### PDF Button Placement

| Layout | ตำแหน่ง |
| --- | --- |
| Desktop/wide | ชิดขวาของ Pagination Bar |
| Tablet/narrow | ชิดขวาแถวบนของ Pagination Bar |
| Mobile/narrow | ชิดขวาแถวบน, pagination เลื่อนอยู่แถวล่าง |

### PDF Button Style

| คุณสมบัติ | ค่า |
| --- | --- |
| widget | `PopupMenuButton` |
| tooltip | `สร้างรายงาน PDF` |
| popup position | `PopupMenuPosition.under` |
| button padding | horizontal `14`, vertical `9` |
| radius | `8` |
| background light | `Color(0xFFFFF3EE)` |
| border light | `Color(0xFFE8622A)` alpha `0.4` |
| icon | `Icons.picture_as_pdf` |
| icon size | `17` |
| icon color | `Color(0xFFE8622A)` |
| icon/text gap | `6` |
| label | `PDF` |
| label font size | `12` |
| label weight | `w600` |
| label color | `Color(0xFFE8622A)` |
| loading state | `CircularProgressIndicator`, size `18`, stroke `2` |

### PDF Popup Menu

| Action | Icon | Icon color | Text | Text size |
| --- | --- | --- | --- | --- |
| Preview | `Icons.picture_as_pdf` | `Color(0xFFE8622A)` | `แสดง PDF` | `13` |
| Share | `Icons.share` | `Color(0xFF1565C0)` | `แชร์ PDF` | `13` |
| Save | `Icons.save_alt` | `Color(0xFF388E3C)` | `บันทึก PDF` | `13` |

ภายในแต่ละเมนูใช้ `Row`, icon size `18`, ระยะ icon ถึง text `10`

## Title Icon / Search Field / Surface Colors

ส่วนนี้ใช้รวม token สำคัญของหัวเรื่อง ช่องค้นหา สีหัวเรื่อง สีพื้น และสี ListView ทั้ง light/dark เพื่อให้สร้าง theme ใหม่ได้ตรงกัน

### Header And Page Icon Colors

| Element | Light | Dark |
| --- | --- | --- |
| title bar background | `AppTheme.navy` | `AppTheme.navyDark` |
| title text | `Colors.white` | `Colors.white` |
| title action icon | `Colors.white70` | `Colors.white70` |
| page icon background | `AppTheme.primary` alpha `0.18` | `AppTheme.primary` alpha `0.18` |
| page icon border | `AppTheme.primary` alpha `0.28` | `AppTheme.primary` alpha `0.28` |
| page icon color | `AppTheme.primaryLight` | `AppTheme.primaryLight` |
| module badge bg | `AppTheme.primary` alpha `0.2` | `AppTheme.primary` alpha `0.2` |
| module badge border | `AppTheme.primary` alpha `0.5` | `AppTheme.primary` alpha `0.5` |
| module badge text | `AppTheme.primaryLight` | `AppTheme.primaryLight` |

### Search Field Colors

| Element | Light | Dark |
| --- | --- | --- |
| field height | `40` | `40` |
| fill | `Colors.white` | `AppTheme.darkElement` |
| text | `Color(0xFF1A1A1A)` | `Color(0xFFE0E0E0)` |
| hint | `AppTheme.textSub` | `Color(0xFF9E9E9E)` |
| prefix icon | `AppTheme.textSub` | `Color(0xFF9E9E9E)` |
| clear icon | default icon color | default icon color หรือ `Color(0xFF9E9E9E)` |
| border | `AppTheme.border` | `Color(0xFF333333)` |
| focused border | `AppTheme.primary`, width `1.5` | `AppTheme.primaryLight` หรือ `AppTheme.primary`, width `1.5` |
| radius | `8` | `8` |
| text size | `13` | `13` |
| hint size | `13` | `13` |
| prefix icon size | `17` | `17` |
| clear icon size | `15` | `15` |

### Page And ListView Surface Colors

| Element | Light | Dark |
| --- | --- | --- |
| scaffold background | `AppTheme.surface` | `AppTheme.darkBg` |
| title bar background | `AppTheme.navy` | `AppTheme.navyDark` |
| summary background | `Color(0xFFFFF8F5)` | `Color(0xFF181818)` |
| content panel background | `Colors.white` | `Color(0xFF2C2C2C)` |
| ListView background | inherited from content panel | `Color(0xFF2C2C2C)` |
| list item card background | `Colors.white` | `Color(0xFF2C2C2C)` |
| list/card border | `AppTheme.border` | `Color(0xFF333333)` |
| list divider | `AppTheme.border` | `Color(0xFF333333)` |
| footer background | `AppTheme.headerBg` | `AppTheme.navyDark` |

## Product List Color Tokens

ชุดสีเฉพาะของหน้า `รายการสินค้า` ที่ควรย้ายเข้า Theme ใหม่

| Token | Light | Dark |
| --- | --- | --- |
| `productList.scaffoldBg` | `AppTheme.surface` | `AppTheme.darkBg` |
| `productList.cardBg` | `Colors.white` | `Color(0xFF2C2C2C)` |
| `productList.border` | `AppTheme.border` | `Color(0xFF333333)` |
| `productList.text` | `Color(0xFF1A1A1A)` | `Color(0xFFE0E0E0)` |
| `productList.subtext` | `AppTheme.textSub` | `Color(0xFF9E9E9E)` |
| `productList.topBarBg` | `AppTheme.navy` | `AppTheme.navyDark` |
| `productList.summaryBg` | `Color(0xFFFFF8F5)` | `Color(0xFF181818)` |
| `productList.summaryChipBg` | `Colors.white` | `Color(0xFF2C2C2C)` |
| `productList.inputFill` | `Colors.white` | `AppTheme.darkElement` |
| `productList.emptyIconBg` | `AppTheme.surface` | `AppTheme.darkCard` |
| `productList.emptyIcon` | `Colors.grey` | `Color(0xFF9E9E9E)` |
| `productList.navButtonBg` | `AppTheme.navyLight` | `Colors.white` alpha `0.08` |
| `productList.navButtonBorder` | `AppTheme.navy` | `Colors.white24` |
| `productList.rowHoverBg` | `AppTheme.primaryLight` | `AppTheme.primaryLight` alpha `0.15` |
| `productList.tableHeaderBg` | `AppTheme.navy` | `AppTheme.navyDark` |
| `productList.headerText` | `Colors.white70` | `Color(0xFFE0E0E0)` |
| `productList.amountText` | `AppTheme.info` | `AppTheme.primaryLight` |
| `productList.costText` | `Color(0xFF666666)` | `Color(0xFFBDBDBD)` |
| `productList.rowIndexText` | `Color(0xFFBBBBBB)` | `Color(0xFF8F8F8F)` |

## Summary Bar Components

### Summary Bar

| คุณสมบัติ | ค่า |
| --- | --- |
| background light | `Color(0xFFFFF8F5)` |
| background dark | `Color(0xFF181818)` |
| border | bottom border ใช้ `ProductList.border` |
| padding | horizontal `16`, vertical `10` |
| layout | horizontal scroll เมื่อพื้นที่ไม่พอ |
| content min width | อย่างน้อยเท่าความกว้างพื้นที่ด้วย `ConstrainedBox(minWidth: constraints.maxWidth)` |
| main alignment | `MainAxisAlignment.spaceBetween` |
| left group | กลุ่มจำนวนสินค้า |
| right group | กลุ่มมูลค่าสินค้าในคลัง |
| group spacing | `16` ระหว่าง left group และ right group |
| item spacing | `8` ระหว่าง chip/stat แต่ละตัว |

### Summary Bar Placement

ตำแหน่งอยู่ใต้ Title Bar และอยู่เหนือ Content Panel ของรายการสินค้า

| ลำดับ | Component |
| --- | --- |
| 1 | Product Page Title / Top Bar |
| 2 | Summary Bar |
| 3 | Content Panel ที่ครอบ Table View หรือ Card View |
| 4 | Pagination Bar |

โครงสร้างภายใน Summary Bar

| ฝั่ง | ตำแหน่ง | Items |
| --- | --- | --- |
| ซ้าย | เริ่มต้นแนวนอน | `ทั้งหมด`, `กรองแล้ว`, `ใช้งาน`, `ปิดใช้`, label คลัง เช่น `ทุกคลัง` |
| กลาง | flexible space | เว้นพื้นที่ด้วย `MainAxisAlignment.spaceBetween` |
| ขวา | ชิดขวาแนวนอน | `ต้นทุนรวม (...)`, `มูลค่าขาย`, `กำไรคาดการณ์` / `ขาดทุนคาดการณ์` |

### Summary Chip

| คุณสมบัติ | ค่า |
| --- | --- |
| padding | horizontal `10`, vertical `5` |
| radius | `999` |
| background | `productList.summaryChipBg` |
| border | `productList.border` |
| label size | `11` |
| count padding | horizontal `6`, vertical `1` |
| count radius | `8` |
| count size | `11` |
| count weight | `bold` |
| label color light | display color alpha `0.88` |
| label color dark | display color alpha `0.78` |
| count background light | display color alpha `1` |
| count background dark | display color alpha `0.88` |
| count text color | `Colors.white` |

### Summary Count Chips

กลุ่มนี้วางอยู่ฝั่งซ้ายของ Summary Bar และใช้ `Row(mainAxisSize: MainAxisSize.min)`

| Label | Value | Base color | Dark display color | ความหมาย |
| --- | --- | --- | --- | --- |
| `ทั้งหมด` | จำนวนสินค้าทั้งหมด `all.length` | `AppTheme.info` | `Color(0xFF7CB7FF)` | จำนวนสินค้าทั้งหมดในระบบ |
| `กรองแล้ว` | จำนวนสินค้าหลัง filter `filtered.length` | `AppTheme.primary` | `AppTheme.primaryLight` | จำนวนสินค้าที่ตรงกับการค้นหา/ตัวกรอง |
| `ใช้งาน` | จำนวนสินค้า active | `AppTheme.success` | `Color(0xFF7FD483)` | สินค้าที่เปิดใช้งาน |
| `ปิดใช้` | จำนวนสินค้า inactive | `AppTheme.error` | `Color(0xFFFF8A80)` | สินค้าที่ปิดใช้งาน |
| label คลัง เช่น `ทุกคลัง` | จำนวนคงเหลือรวม `totalQty.round()` | `AppTheme.info` | `Color(0xFF7CB7FF)` | จำนวนสินค้าคงเหลือรวมตามคลังที่เลือก |

หมายเหตุ: ถ้าข้อความใน UI ใช้คำว่า `ทุกครั้ง` ให้ถือเป็น label ที่ส่งมาจากตัวกรอง/สถานะปัจจุบัน และใช้ style เดียวกับ chip label คลัง

### Summary Chip Text Rules

| Element | ขนาด | Weight | สี | ตำแหน่ง |
| --- | --- | --- | --- | --- |
| chip label | `11` | default | display color alpha `0.88` light / `0.78` dark | ด้านซ้ายใน chip |
| chip count | `11` | `bold` | `Colors.white` | อยู่ใน badge ด้านขวาของ chip |
| chip count badge | - | - | background เป็น display color | หลัง label ระยะ `4` |

ตัวอย่างลำดับการวาง

1. `ทั้งหมด` badge count
2. ระยะ `8`
3. `กรองแล้ว` badge count
4. ระยะ `8`
5. `ใช้งาน` badge count
6. ระยะ `8`
7. `ปิดใช้` badge count
8. ระยะ `8`
9. `ทุกคลัง` หรือ label คลัง badge count

### Value Stat

| คุณสมบัติ | Medium | High |
| --- | --- | --- |
| padding | horizontal `10`, vertical `6` | horizontal `12`, vertical `7` |
| radius | `999` | `999` |
| background | `summaryChipBg` | display color alpha `0.12` light / `0.18` dark |
| border | `productList.border` | display color alpha `0.24` light / `0.34` dark |
| label size | `10` | `10` |
| value size | `13` | `14.5` |
| value weight | `bold` | `bold` |
| label opacity | `0.76` | `0.92` |
| layout | `Column(crossAxisAlignment: CrossAxisAlignment.start)` | เหมือนกัน |
| label to value spacing | `1` | `1` |

### Summary Value Stats

กลุ่มนี้วางอยู่ฝั่งขวาของ Summary Bar และใช้ `Row(mainAxisSize: MainAxisSize.min)`

| Label | Value format | Base color | Dark display color | Emphasis | ตำแหน่ง |
| --- | --- | --- | --- | --- | --- |
| `ต้นทุนรวม (...)` | `฿#,##0.00` | `AppTheme.navy` | `Color(0xFFE0E0E0)` | medium | ตัวแรกของกลุ่มขวา |
| `มูลค่าขาย` | `฿#,##0.00` | `AppTheme.primaryDark` | `AppTheme.primaryLight` | medium | ต่อจากต้นทุนรวม ระยะ `8` |
| `กำไรคาดการณ์` | `+฿#,##0.00` | `AppTheme.success` | `Color(0xFF7FD483)` | high | ต่อจากมูลค่าขาย ระยะ `8` |
| `ขาดทุนคาดการณ์` | `-฿#,##0.00` | `AppTheme.error` | `Color(0xFFFF8A80)` | high | ใช้แทนกำไรเมื่อค่าติดลบ |

### Value Stat Text Rules

| Element | Medium | High |
| --- | --- | --- |
| label font size | `10` | `10` |
| label weight | default | default |
| label color | display color alpha `0.76` | display color alpha `0.92` |
| value font size | `13` | `14.5` |
| value weight | `bold` | `bold` |
| value color | display color | display color |

### Summary Bar Responsive Rules

| เงื่อนไข | พฤติกรรม |
| --- | --- |
| พื้นที่พอ | left group ชิดซ้าย และ right group ชิดขวา |
| พื้นที่ไม่พอ | ใช้ horizontal scroll ทั้ง Summary Bar |
| chip/stat ยาว | ห้ามบีบข้อความจนตัด ให้เลื่อนแนวนอนแทน |
| mobile/compact | ยังคงลำดับเดิม แต่ผู้ใช้เลื่อนดูด้านขวาได้ |

## Dark Mode Theme

แนวทางโหมดมืดของแอพควรเน้นความอ่านง่าย ลด glare และคง hierarchy ของ UI ให้ชัดเจนโดยไม่ใช้ shadow หนัก สีควรถูกจัดเป็น layer แทนการใช้สีดำล้วนทุกพื้นที่

### Dark Mode Policy

| เรื่อง | แนวทาง |
| --- | --- |
| background หลัก | ใช้พื้นหลังเข้มที่สุดกับ scaffold |
| surface/card | ใช้สีอ่อนกว่า scaffold 1-2 ระดับ เพื่อแยกชั้นข้อมูล |
| border | ใช้ border บางสีเทาเข้มแทน shadow |
| shadow | ลดหรือปิด shadow ใน dark mode |
| text หลัก | ใช้เทาอ่อน ไม่จำเป็นต้องขาวล้วนทุกจุด |
| text รอง | ใช้เทากลางเพื่อไม่แย่งความสำคัญ |
| primary/accent | ใช้เฉดที่สว่างขึ้นกว่าบน light mode |
| hover/selected | ใช้ accent alpha ต่ำ ไม่ใช้พื้นหลังทึบจัด |
| input | แยกจาก card ด้วยพื้น fill ที่เข้ม/อ่อนกว่าพื้นรอบข้างเล็กน้อย |
| divider | ใช้สีเดียวกับ border และความสูง `1` |

### Dark Core Tokens

ค่าเหล่านี้อิงจากหน้า `รายการสินค้า` และชื่อเดิมของ `AppTheme`

| Token ใหม่ | ค่าอ้างอิง | ใช้กับ |
| --- | --- | --- |
| `dark.scaffold` | `AppTheme.darkBg` | พื้นหลังหน้าหลัก |
| `dark.surface` | `AppTheme.darkCard` | panel/card ทั่วไป |
| `dark.surfaceRaised` | `Color(0xFF2C2C2C)` | card item, chip, dropdown surface |
| `dark.surfaceMuted` | `AppTheme.darkElement` | input fill, nested controls |
| `dark.topBar` | `AppTheme.navyDark` | title/top bar |
| `dark.summary` | `Color(0xFF181818)` | summary bar |
| `dark.border` | `Color(0xFF333333)` | card/list/table border |
| `dark.inputBorder` | `Colors.white24` หรือ `Color(0xFF333333)` | input และ nav button border |
| `dark.text` | `Color(0xFFE0E0E0)` | primary text |
| `dark.textMuted` | `Color(0xFF9E9E9E)` | secondary text |
| `dark.textSubtle` | `Color(0xFF8F8F8F)` | row index, helper text |
| `dark.iconMuted` | `Colors.white70` | icon บน top bar |
| `dark.iconDisabled` | `Colors.white38` | icon disabled/subtle |

### Dark Product List Mapping

| Component | Dark value |
| --- | --- |
| page scaffold | `AppTheme.darkBg` |
| top bar | `AppTheme.navyDark` |
| content panel | `Color(0xFF2C2C2C)` |
| product item card | `Color(0xFF2C2C2C)` |
| card/list border | `Color(0xFF333333)` |
| summary bar | `Color(0xFF181818)` |
| summary chip | `Color(0xFF2C2C2C)` |
| search field fill | `AppTheme.darkElement` |
| dropdown surface | `Color(0xFF2C2C2C)` |
| table header | `AppTheme.navyDark` |
| empty icon background | `AppTheme.darkCard` |
| nav button background | `Colors.white` alpha `0.08` |
| nav button border | `Colors.white24` |
| row hover | `AppTheme.primaryLight` alpha `0.15` |
| footer / pagination bar | `AppTheme.navyDark` |
| footer count text | `Colors.white60` |
| footer page button bg | `Colors.white` alpha `0.10` |
| footer page button border | `Colors.white` alpha `0.22` |
| PDF button bg | ควรใช้ `Color(0xFFE8622A)` alpha `0.12` |
| PDF button border | `Color(0xFFE8622A)` alpha `0.35` |
| PDF button text/icon | `Color(0xFFFF9A73)` หรือ `Color(0xFFE8622A)` ถ้า contrast ผ่าน |

### Dark Responsive Color Matrix

สีหลักของโหมดมืดต้องคง identity เดียวกันทุก device แต่ปรับ contrast และพื้นผิวตาม density ของหน้าจอ

| UI Token | Mobile | Tablet | Desktop |
| --- | --- | --- | --- |
| `dark.scaffold` | `AppTheme.darkBg` | `AppTheme.darkBg` | `AppTheme.darkBg` |
| `dark.topBar` | `AppTheme.navyDark` | `AppTheme.navyDark` | `AppTheme.navyDark` |
| `dark.contentPanel` | `Color(0xFF242424)` | `Color(0xFF282828)` | `Color(0xFF2C2C2C)` |
| `dark.card` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` |
| `dark.cardNested` | `AppTheme.darkElement` | `AppTheme.darkElement` | `AppTheme.darkElement` |
| `dark.summaryBar` | `Color(0xFF181818)` | `Color(0xFF181818)` | `Color(0xFF181818)` |
| `dark.summaryChip` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` |
| `dark.inputFill` | `AppTheme.darkElement` | `AppTheme.darkElement` | `AppTheme.darkElement` |
| `dark.dropdown` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` | `Color(0xFF2C2C2C)` |
| `dark.footer` | `AppTheme.navyDark` | `AppTheme.navyDark` | `AppTheme.navyDark` |
| `dark.pdfButtonBg` | `Color(0xFFE8622A)` alpha `0.12` | `Color(0xFFE8622A)` alpha `0.12` | `Color(0xFFE8622A)` alpha `0.12` |
| `dark.pdfButtonBorder` | `Color(0xFFE8622A)` alpha `0.35` | `Color(0xFFE8622A)` alpha `0.35` | `Color(0xFFE8622A)` alpha `0.35` |
| `dark.border` | `Color(0xFF3A3A3A)` | `Color(0xFF333333)` | `Color(0xFF333333)` |
| `dark.divider` | `Color(0xFF333333)` | `Color(0xFF333333)` | `Color(0xFF333333)` |
| `dark.hover` | ไม่มี hover, ใช้ pressed state | `AppTheme.primaryLight` alpha `0.12` | `AppTheme.primaryLight` alpha `0.15` |
| `dark.selected` | accent alpha `0.14` | accent alpha `0.12` | accent alpha `0.10` |

หมายเหตุ: Mobile ใช้ border สว่างขึ้นเล็กน้อย (`0xFF3A3A3A`) เพื่อแยก card ที่เต็มความกว้างได้ชัดขึ้น ส่วน Desktop ใช้ border นุ่มกว่าเพราะมีพื้นที่และ hierarchy จาก layout ช่วยอยู่แล้ว

### Dark Responsive Typography

| Element | Mobile | Tablet | Desktop |
| --- | --- | --- | --- |
| page title | `15`, `w600`, `Colors.white` | `15-16`, `w600`, `Colors.white` | `16`, `w600`, `Colors.white` |
| card title | `13`, `w600`, `Color(0xFFE0E0E0)` | `13`, `w600`, `Color(0xFFE0E0E0)` | `13`, `w600`, `Color(0xFFE0E0E0)` |
| card metadata | `11`, regular, `Color(0xFF9E9E9E)` | `11`, regular, `Color(0xFF9E9E9E)` | `11`, regular, `Color(0xFF9E9E9E)` |
| amount/value | `12-13`, bold, `AppTheme.primaryLight` | `13`, bold, `AppTheme.primaryLight` | `13`, bold, `AppTheme.primaryLight` |
| summary chip label | `11`, regular, display alpha `0.78` | `11`, regular, display alpha `0.78` | `11`, regular, display alpha `0.78` |
| summary stat label | `10`, regular, display alpha `0.76` | `10`, regular, display alpha `0.76` | `10`, regular, display alpha `0.76` |

### Dark Mobile Rules

| Area | Rule |
| --- | --- |
| title bar | ใช้ compact 2 rows, action เป็น icon compact, สี icon `Colors.white70` |
| search/dropdown | ใช้ `dark.inputFill`, border `dark.border`, text `dark.text` |
| summary bar | ใช้ horizontal scroll เสมอเมื่อ content ยาว |
| cards | ใช้ card เต็มพื้นที่ อ่านทีละรายการ, border ชัดขึ้น |
| actions | icon button ขนาดอย่างน้อย `32`, touch area ควรขยายได้ถึง `40` |
| hover | ไม่มี hover state ให้ใช้ pressed/selected alpha แทน |

### Dark Tablet Rules

| Area | Rule |
| --- | --- |
| title bar | ใช้ compact หรือ wide ตามพื้นที่จริง ถ้า action ล้นให้แยก search เป็นแถวที่ 2 |
| summary bar | ใช้ space-between เมื่อพอ และ fallback เป็น horizontal scroll |
| cards/table | ใช้ Card View หรือ Table View ได้ แต่ต้องคงสี `dark.card` และ `dark.border` |
| action buttons | icon compact เป็นค่าเริ่มต้น ปุ่ม label ใช้เมื่อพื้นที่พอ |
| content width | จำกัด content ประมาณ `800` เมื่อต้องการอ่านแบบ focused |

### Dark Desktop Rules

| Area | Rule |
| --- | --- |
| title bar | ใช้ wide 1 row, title ซ้าย controls ขวา |
| summary bar | left group ชิดซ้าย right group ชิดขวา |
| table/header | header ใช้ `AppTheme.navyDark`, text `Color(0xFFE0E0E0)` |
| content panel | ใช้ `Color(0xFF2C2C2C)`, border `Color(0xFF333333)`, ไม่มี shadow |
| hover | ใช้ `AppTheme.primaryLight` alpha `0.15` |
| sidebar | ใช้ permanent sidebar ตั้งแต่ `1024` ขึ้นไป |

### Dark Typography Colors

| Element | Dark color |
| --- | --- |
| primary text | `Color(0xFFE0E0E0)` |
| secondary text | `Color(0xFF9E9E9E)` |
| table/header text | `Color(0xFFE0E0E0)` |
| amount text | `AppTheme.primaryLight` |
| cost text | `Color(0xFFBDBDBD)` |
| row index text | `Color(0xFF8F8F8F)` |
| title text | `Colors.white` |
| title icon/action default | `Colors.white70` |

### Dark Accent Mapping

สี semantic บางสีต้องปรับให้สว่างขึ้นใน dark mode เพื่ออ่านง่าย

| Base token | Dark display color |
| --- | --- |
| `AppTheme.navy` | `Color(0xFFE0E0E0)` |
| `AppTheme.primaryDark` | `AppTheme.primaryLight` |
| `AppTheme.primary` | `AppTheme.primaryLight` |
| `AppTheme.info` | `Color(0xFF7CB7FF)` |
| `AppTheme.success` | `Color(0xFF7FD483)` |
| `AppTheme.error` | `Color(0xFFFF8A80)` |

### Dark Card Rules

| Element | Rule |
| --- | --- |
| card background | ใช้ `dark.surfaceRaised` เมื่อ card อยู่บน scaffold หรือ panel |
| card border | ใช้ `dark.border` เสมอ |
| card shadow | ปิด shadow หรือใช้เฉพาะกรณีจำเป็นมาก |
| nested chip/badge | ใช้ alpha ของ semantic color เพื่อไม่ให้สว่างเกิน |
| icon button background | ใช้ action color alpha `0.08` หรือ white alpha `0.08` |
| icon button border | ใช้ action color alpha `0.18` หรือ `Colors.white24` |

### Dark Input Rules

| Element | Rule |
| --- | --- |
| input fill | `dark.surfaceMuted` |
| input text | `dark.text` |
| hint text | `dark.textMuted` |
| prefix/suffix icon | `dark.textMuted` |
| normal border | `dark.border` |
| focused border | primary/accent color width `1.5` |
| dropdown background | `dark.surfaceRaised` |

### Dark Mode Implementation Notes

- ตรวจ dark mode จาก `Theme.of(context).brightness == Brightness.dark`
- อย่า hardcode `Colors.black` เป็นพื้นหลังหลัก ยกเว้นกรณี media/fullscreen เฉพาะทาง
- ใช้ alpha กับสี accent สำหรับ selected/hover/focus state
- ใช้ border เพื่อแยกชั้น card แทน shadow
- สี semantic container ของ success/error/warning/info ต้องทดสอบ contrast กับข้อความใน dark mode
- ถ้าใช้สีเดิมจาก light mode แล้วอ่านยาก ให้เพิ่ม token `displayColor` สำหรับ dark mode โดยเฉพาะ

## Pending Sections

รอข้อมูลเพิ่มเติมจากผู้ใช้เพื่อเติมหัวข้อต่อไป

- Global color palette
- Typography scale
- Button theme
- Form input theme
- Table theme
- Dialog theme
- Navigation / top bar theme
