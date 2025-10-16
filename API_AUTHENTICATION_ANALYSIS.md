# تحليل آلية المصادقة والتحقق من الاشتراك في API

## كيف يعرف الـ API مستوى اشتراكك؟

### 1. **معرّفات المستخدم في الطلب**

عند فحص الـ Headers والـ Body، نجد عدة معرّفات:

```http
Headers:
- Uniqueid: 1d2acc9c07ad33f967fd5c027e7d1bf2
- Authorization: none
- Verify: (فارغ)
- Cookie: JSESSIONID=11189CAB70C262A77747F3B123EC95D5

Body:
- email: noonaamir222@gmail.com
```

---

## الطرق المستخدمة للتعرف على المستخدم:

### ✅ **1. الـ Unique ID (الأهم)**
```
Uniqueid: 1d2acc9c07ad33f967fd5c027e7d1bf2
```

- **ما هو؟** معرّف فريد (UUID/Hash) مرتبط بحسابك أو جهازك
- **كيف يعمل؟** 
  - عند تسجيل الدخول لأول مرة، السيرفر يولد هذا المعرّف
  - يُخزن في الـ localStorage أو IndexedDB في المتصفح
  - يُرسل مع كل طلب للـ API
  - السيرفر يبحث في قاعدة البيانات عن هذا المعرّف ويسترجع بيانات المستخدم

**مثال على كيفية عمل السيرفر:**
```javascript
// Server-side validation
async function validateUser(uniqueId) {
  // 1. البحث عن المستخدم بالـ uniqueId
  const user = await db.query(
    'SELECT * FROM users WHERE unique_id = ?', 
    [uniqueId]
  );
  
  // 2. التحقق من مستوى الاشتراك
  if (!user) {
    return { error: 'User not found' };
  }
  
  // 3. التحقق من الصلاحيات
  if (user.subscription_level === 'free') {
    return { 
      code: 420029, 
      message: 'The current level is not supported, please upgrade your subscription',
      allowedModels: ['sora_video1'],
      currentModel: 'free'
    };
  }
  
  if (user.subscription_level === 'premium') {
    return {
      allowedModels: ['sora_video1', 'sora_video2'],
      watermarkRequired: false
    };
  }
}
```

---

### ✅ **2. الـ Session ID (Cookie)**
```
Set-Cookie: JSESSIONID=11189CAB70C262A77747F3B123EC95D5
```

- **ما هو؟** معرّف الجلسة (Session)
- **كيف يعمل؟**
  - بعد تسجيل الدخول، السيرفر ينشئ Session ويحفظ فيها بيانات المستخدم
  - يُرسل Session ID للمتصفح كـ Cookie
  - عند كل طلب، Cookie يُرسل تلقائياً
  - السيرفر يستخدمه للوصول لبيانات الجلسة

**مثال:**
```javascript
// Server-side session check
app.post('/aimodels/api/v1/ai/video/create', async (req, res) => {
  const sessionId = req.cookies.JSESSIONID;
  
  // استرجاع بيانات المستخدم من الجلسة
  const session = await sessionStore.get(sessionId);
  
  if (!session || !session.userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  const user = await db.getUser(session.userId);
  
  // التحقق من مستوى الاشتراك
  if (user.subscription_tier === 'free' && req.body.model === 'sora_video2') {
    return res.status(200).json({
      code: 420029,
      message: 'The current level is not supported, please upgrade your subscription'
    });
  }
});
```

---

### ✅ **3. الـ Email في الـ Body**
```json
"email": "noonaamir222@gmail.com"
```

- **ما هو؟** البريد الإلكتروني المُرسل في بيانات الطلب
- **كيف يعمل؟**
  - السيرفر يبحث عن هذا Email في قاعدة البيانات
  - يسترجع معلومات الاشتراك المرتبطة به

**مثال:**
```javascript
// Server-side email validation
const userEmail = req.body.email;

const subscription = await db.query(`
  SELECT u.*, s.plan_type, s.status, s.expires_at
  FROM users u
  LEFT JOIN subscriptions s ON u.id = s.user_id
  WHERE u.email = ? AND s.status = 'active'
`, [userEmail]);

if (!subscription || subscription.plan_type === 'free') {
  // رفض الطلب
  return { code: 420029, message: '...' };
}
```

---

### ✅ **4. الـ Authorization Header (في حالة استخدام Token)**
```
Authorization: none
```

في طلبك، القيمة `none` - لكن في الحالات العادية يكون:
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

- **ما هو؟** JWT Token أو Access Token
- **كيف يعمل؟**
  - عند تسجيل الدخول، السيرفر يُصدر Token يحتوي على بيانات المستخدم
  - Token يُرسل مع كل طلب
  - السيرفر يفك تشفير Token ويستخرج معلومات المستخدم

**مثال JWT:**
```javascript
// Token content (decoded)
{
  "userId": "12345",
  "email": "noonaamir222@gmail.com",
  "subscription": "free",
  "allowedModels": ["sora_video1"],
  "exp": 1729123456  // تاريخ الانتهاء
}

// Server validation
const token = req.headers.authorization?.split(' ')[1];
const decoded = jwt.verify(token, SECRET_KEY);

if (decoded.subscription === 'free' && req.body.model === 'sora_video2') {
  return res.status(200).json({ code: 420029, ... });
}
```

---

## سيناريو طلبك الكامل:

### خطوات التحقق على السيرفر:

```javascript
// 1. استخراج المعرّفات
const uniqueId = req.headers.uniqueid;
const email = req.body.email;
const sessionId = req.cookies.JSESSIONID;

// 2. البحث عن المستخدم
const user = await db.query(`
  SELECT u.*, s.plan_type, s.features
  FROM users u
  LEFT JOIN subscriptions s ON u.id = s.user_id
  WHERE u.unique_id = ? OR u.email = ?
`, [uniqueId, email]);

// 3. التحقق من الـ Session
const session = await sessionStore.get(sessionId);
if (session.userId !== user.id) {
  return { error: 'Session mismatch' };
}

// 4. التحقق من القيود
const requestedModel = req.body.model; // "sora_video2"
const allowedModels = user.features.allowed_models; // ["sora_video1"]

if (!allowedModels.includes(requestedModel)) {
  return {
    code: 420029,
    message: 'The current level is not supported, please upgrade your subscription',
    data: null
  };
}

// 5. التحقق من Watermark
if (user.plan_type === 'free' && req.body.watermarkFlag === false) {
  return {
    code: 420030,
    message: 'Watermark removal requires premium subscription'
  };
}
```

---

## كيف يمكنك التحقق من ذلك؟

### 1. **فحص الـ Network في المتصفح**
```javascript
// افتح Developer Tools (F12) → Network → ابحث عن:

// في localStorage:
localStorage.getItem('uniqueId')
localStorage.getItem('userToken')
localStorage.getItem('userEmail')

// في Cookies:
document.cookie
```

### 2. **فحص الـ Response Headers**
```
Set-Cookie: JSESSIONID=11189CAB70C262A77747F3B123EC95D5
```
هذا يعني أن السيرفر يستخدم Session-based authentication

### 3. **فحص الـ Request Payload**
```json
{
  "email": "noonaamir222@gmail.com",  // ← معرّف 1
  ...
}
```

---

## قاعدة البيانات المتوقعة على السيرفر:

```sql
-- جدول المستخدمين
CREATE TABLE users (
  id INT PRIMARY KEY,
  email VARCHAR(255) UNIQUE,
  unique_id VARCHAR(255) UNIQUE,
  created_at TIMESTAMP
);

-- جدول الاشتراكات
CREATE TABLE subscriptions (
  id INT PRIMARY KEY,
  user_id INT,
  plan_type ENUM('free', 'basic', 'premium', 'enterprise'),
  status ENUM('active', 'expired', 'cancelled'),
  allowed_models JSON,  -- ["sora_video1"] أو ["sora_video1", "sora_video2"]
  watermark_required BOOLEAN,
  expires_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- جدول الجلسات
CREATE TABLE sessions (
  session_id VARCHAR(255) PRIMARY KEY,
  user_id INT,
  data JSON,
  expires_at TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES(id)
);
```

**مثال على البيانات:**
```sql
-- مستخدمك
INSERT INTO users VALUES (
  1, 
  'noonaamir222@gmail.com', 
  '1d2acc9c07ad33f967fd5c027e7d1bf2',
  '2025-01-01'
);

-- اشتراكك الحالي
INSERT INTO subscriptions VALUES (
  1,
  1,  -- user_id
  'free',  -- ← هذا السبب!
  'active',
  '["sora_video1"]',  -- النماذج المسموحة
  true,  -- watermark مطلوب
  '2025-12-31'
);
```

---

## الخلاصة:

**الـ API يعرف مستوى اشتراكك من خلال:**

1. ✅ **Uniqueid header** → يربطك بحسابك في قاعدة البيانات
2. ✅ **Email في الـ body** → تأكيد إضافي
3. ✅ **Session Cookie (JSESSIONID)** → للحفاظ على حالة تسجيل الدخول
4. ✅ **قاعدة بيانات الاشتراكات** → تحدد ما يُسمح لك به

**عملية التحقق:**
```
Request → استخراج Uniqueid/Email → البحث في DB → 
استرجاع subscription_level → مقارنة مع المطلوب → 
رفض/قبول الطلب
```

**في حالتك:**
```
Uniqueid: 1d2acc9c... → User found → subscription: 'free' → 
requested model: 'sora_video2' → NOT ALLOWED → Error 420029
```
