# DEE POS — ระบบ License Key Plan

## สถาปัตยกรรมระบบ

```
Flutter Web (GitHub Pages)
    ├── หน้าแสดงข้อมูล / ราคา
    ├── Google OAuth (google_sign_in)
    ├── Dashboard จัดการ License Key
    ├── ยืนยันการซื้อ / upload slip
    └── แสดง Key ให้ผู้ใช้ copy
            ↓ API call (HTTPS)
PHP + MySQL (Shared Hosting)
    ├── Sign License Key ด้วย RSA Private Key
    ├── เก็บข้อมูล user (email, google_id, plan)
    ├── เก็บ device_id / license key
    └── ยืนยัน payment
            ↓ Public Key ฝังใน App
Flutter App (DEE POS)
    └── ตรวจสอบ License Key (offline ได้)
```

---

## ราคา Subscription

| เดือน | ราคา | หมายเหตุ |
|-------|------|---------|
| เดือนที่ 1 (วันที่ 1–30) | 990 บาท | ช่วงทดลองใช้ฟรี |
| เดือนที่ 2 (วันที่ 31–60) | 1,490 บาท | ช่วงทดลองใช้ฟรี |
| เดือนที่ 3 (วันที่ 61–90) | 1,990 บาท | ช่วงทดลองใช้ฟรี |
| หลังจากนั้น (วันที่ 91+) | 4,990 บาท/เดือน | หมดช่วงทดลอง |

---

## กฎ License Key

- 1 email ออก Key ได้สูงสุด **4 ชุด** (4 device)
- Key ผูกกับ **email + device_id + expire_date**
- Key Sign ด้วย RSA Private Key บน PHP Server
- Flutter App ตรวจ Key ด้วย RSA Public Key (ฝังใน App)
- ตรวจสอบได้ **offline** โดยไม่ต้องเชื่อม server

---

## Flow การลงทะเบียน

```
1. ผู้ใช้เข้า Flutter Web (GitHub Pages)
2. Login ด้วย Google Account
3. จ่ายเงินตามช่วงเวลา (PromptPay / slip)
4. PHP ยืนยัน payment → Sign License Key
5. Flutter Web แสดง Key → ผู้ใช้ copy
6. กรอก Key ใน Flutter App
7. App ตรวจ Key → unlock ฟีเจอร์ทั้งหมด
```

---

## PHP API Endpoints

```
POST /register-device   ← บันทึก device_id + email
POST /sign-key          ← Sign License Key ด้วย Private Key
POST /verify-payment    ← ยืนยัน slip / การชำระเงิน
GET  /get-keys          ← ดึง key list ของ email
POST /revoke-key        ← ยกเลิก key
```

---

## ระบบตรวจสอบวันที่ (ป้องกันโกง)

### บันทึก first_launch_date
```dart
// เปิด App ครั้งแรก
if (prefs.get('first_launch_date') == null) {
  prefs.set('first_launch_date', DateTime.now().toIso8601String());
}
```

### ตรวจสอบเวลา (ป้องกันย้อนนาฬิกา)
```dart
// มีเน็ต → บันทึกคู่นี้ไว้
last_ntp_time = เวลาจาก NTP server
last_device_time = device time ขณะนั้น

// ออฟไลน์ → คำนวณเวลาจริง
real_time = last_ntp_time + (device_now - last_device_time)

// ตรวจจับย้อนนาฬิกา
if (device_now < last_device_time) → แจ้งเตือน
```

### ระบบ Backup ล็อควันที่
```json
{
  "app_meta": {
    "first_launch_date": "2026-01-15",
    "device_id": "abc123xyz",
    "backup_date": "2026-04-19",
    "checksum": "sha256(email + device_id + first_launch_date + secret)"
  },
  "data": {
    "products": [],
    "sales": [],
    "customers": []
  }
}
```

- ผู้ใช้ไม่กล้าทิ้ง backup → ข้อมูลขายสำคัญกว่า → first_launch_date กลับมาเสมอ
- `checksum` ป้องกันผู้ใช้แก้ไข first_launch_date ด้วยมือ

---

## แผน Notification

| วัน | ข้อความ |
|-----|---------|
| 1 | ยินดีต้อนรับ! ทดลองใช้ฟรี 3 เดือน — ลงทะเบียนเดือนนี้เพียง **990 บาท** |
| 15 | เหลืออีก 15 วัน ในราคา 990 บาท — ลงทะเบียนก่อนหมดโปรโมชัน |
| 25 | เหลือ 5 วัน! ราคา 990 บาท หลังจากนี้ขึ้นเป็น **1,490 บาท** |
| 31 | ราคาปรับเป็น **1,490 บาท/เดือน** — ยังทดลองฟรีอยู่ถึงวันที่ 60 |
| 50 | เหลือ 10 วัน ในราคา 1,490 บาท — หลังจากนี้ขึ้นเป็น **1,990 บาท** |
| 61 | ราคาปรับเป็น **1,990 บาท/เดือน** — เหลือเวลาทดลองอีก 30 วัน |
| 80 | เหลือ 10 วัน ก่อนหมดทดลอง — ลงทะเบียน 1,990 บาท ก่อนราคาเต็ม |
| 88 | เหลือ 2 วัน! หลังหมดทดลองราคา **4,990 บาท/เดือน** |
| 91 | หมดช่วงทดลองแล้ว — ลงทะเบียน 4,990 บาท เพื่อใช้งานต่อ |
| 91+ | แจ้งเตือนทุก 3 วัน จนกว่าจะลงทะเบียน |

---

## Feature Lock หลังหมดอายุ

| ฟีเจอร์ | ระหว่างทดลอง | หมดอายุ (ไม่ลงทะเบียน) |
|---------|-------------|----------------------|
| ดูข้อมูลทุกหน้า | ✅ | ✅ |
| สำรองข้อมูล | ✅ | ✅ |
| เพิ่ม / แก้ไข / ลบข้อมูล | ✅ | ❌ |
| ขาย / เปิดบิล | ✅ | ❌ |
| พิมพ์ใบเสร็จ | ✅ | ❌ |
| Export รายงาน | ✅ | ❌ |

---

## MySQL Schema

```sql
-- ผู้ใช้
CREATE TABLE users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  google_email VARCHAR(255) UNIQUE,
  google_id VARCHAR(255),
  plan INT DEFAULT 0,
  plan_start_date DATE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- License Keys
CREATE TABLE license_keys (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  key_hash TEXT,
  device_id VARCHAR(255),
  device_name VARCHAR(255),
  expire_date DATE,
  activated_at TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- การชำระเงิน
CREATE TABLE payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  amount INT,
  month_number INT,
  slip_image VARCHAR(255),
  paid_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  is_verified BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

---

## ลำดับการพัฒนา

| ขั้น | งาน | เครื่องมือ |
|------|-----|-----------|
| 1 | MySQL Schema + PHP API | phpMyAdmin / PHP |
| 2 | Google OAuth ใน PHP | Google Cloud Console |
| 3 | RSA Key Pair (Private บน PHP, Public ใน App) | OpenSSL |
| 4 | PHP: Sign / Verify License Key | PHP openssl functions |
| 5 | Flutter Web: หน้าราคา + Google Login | Flutter Web |
| 6 | Flutter Web: Dashboard + แสดง Key | Flutter Web |
| 7 | Flutter App: บันทึก first_launch_date | SharedPreferences |
| 8 | Flutter App: ระบบตรวจเวลา (NTP + offline) | ntp package |
| 9 | Flutter App: Backup ใส่ first_launch_date + checksum | dart:convert |
| 10 | Flutter App: Notification ตามวัน | flutter_local_notifications |
| 11 | Flutter App: Feature Lock หลังหมดอายุ | - |
| 12 | Flutter App: ตรวจ Key + unlock features | pointycastle |

---

## ความปลอดภัย

- **Private Key** เก็บบน PHP Server เท่านั้น — ห้ามอยู่ใน Flutter Web
- **Public Key** ฝังใน Flutter App สำหรับตรวจ Key offline
- **Checksum** ใน backup ป้องกันแก้ไข first_launch_date
- **HTTPS** บังคับทุก API call
- **device_id** ผูกกับ Key ป้องกัน share Key ข้าม device
