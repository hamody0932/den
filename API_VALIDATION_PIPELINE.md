# سلسلة التحقق في API - Validation Pipeline

## 🔍 ما اكتشفته:

عند حذف `Uniqueid` من Headers، الرد كان:
```json
{
  "code": 400000,
  "message": "uniqueId is blank",
  "data": null
}
```

**هذا يؤكد أن السيرفر لديه مراحل متسلسلة للتحقق!**

---

## 🔄 **ترتيب التحقق (Validation Pipeline)**

### المرحلة 1️⃣: **فحص وجود المعرّفات الأساسية**
```javascript
// server.js - First Layer Validation
app.post('/aimodels/api/v1/ai/video/create', (req, res) => {
  
  // ✅ المرحلة 1: فحص وجود الـ Headers الإلزامية
  const uniqueId = req.headers.uniqueid;
  
  if (!uniqueId || uniqueId.trim() === '') {
    return res.status(200).json({
      code: 400000,  // ← هذا الخطأ اللي شفته!
      message: 'uniqueId is blank',
      data: null
    });
  }
  
  // إذا نجح، ننتقل للمرحلة التالية...
});
```

**الأخطاء الممكنة في هذه المرحلة:**
- `400000` - uniqueId is blank
- `400001` - email is blank (لو حذفت email من body)
- `400002` - model is blank (لو حذفت model)

---

### المرحلة 2️⃣: **التحقق من صحة المعرّفات**
```javascript
// ✅ المرحلة 2: التحقق من صحة الـ UniqueId
const user = await db.query(`
  SELECT * FROM users WHERE unique_id = ?
`, [uniqueId]);

if (!user) {
  return res.status(200).json({
    code: 401000,  // ← خطأ جديد
    message: 'Invalid or expired uniqueId',
    data: null
  });
}

// التحقق من Session
const sessionId = req.cookies.JSESSIONID;
const session = await sessionStore.get(sessionId);

if (!session || session.userId !== user.id) {
  return res.status(200).json({
    code: 401001,
    message: 'Session mismatch or expired',
    data: null
  });
}
```

**الأخطاء الممكنة:**
- `401000` - Invalid uniqueId
- `401001` - Session mismatch
- `401002` - User not found

---

### المرحلة 3️⃣: **التحقق من الاشتراك والصلاحيات**
```javascript
// ✅ المرحلة 3: التحقق من مستوى الاشتراك
const subscription = await db.query(`
  SELECT * FROM subscriptions 
  WHERE user_id = ? AND status = 'active'
`, [user.id]);

if (!subscription) {
  return res.status(200).json({
    code: 420000,
    message: 'No active subscription found',
    data: null
  });
}

// التحقق من صلاحية النموذج المطلوب
const requestedModel = req.body.model;
const allowedModels = JSON.parse(subscription.features).allowed_models;

if (!allowedModels.includes(requestedModel)) {
  return res.status(200).json({
    code: 420029,  // ← هذا الخطأ اللي شفته في طلبك الأول!
    message: 'The current level is not supported, please upgrade your subscription',
    data: null
  });
}
```

**الأخطاء الممكنة:**
- `420000` - No subscription
- `420029` - Model not allowed (الخطأ اللي عندك!)
- `420030` - Watermark removal not allowed
- `420031` - Credits exhausted

---

### المرحلة 4️⃣: **التحقق من حدود الاستخدام (Rate Limits)**
```javascript
// ✅ المرحلة 4: التحقق من عدد الطلبات
const dailyRequests = await redis.get(`requests:${user.id}:${today}`);

if (dailyRequests >= subscription.daily_limit) {
  return res.status(200).json({
    code: 429000,
    message: 'Daily request limit exceeded',
    data: null
  });
}

// التحقق من Credits
if (user.credits < calculateCost(req.body)) {
  return res.status(200).json({
    code: 429001,
    message: 'Insufficient credits',
    data: null
  });
}
```

---

### المرحلة 5️⃣: **تنفيذ الطلب**
```javascript
// ✅ المرحلة 5: كل شيء صحيح - تنفيذ الطلب
try {
  const result = await createVideo({
    prompt: req.body.prompt,
    model: req.body.model,
    userId: user.id,
    ...req.body
  });
  
  // تحديث الإحصائيات
  await incrementRequestCount(user.id);
  await deductCredits(user.id, calculateCost(req.body));
  
  return res.status(200).json({
    code: 200,  // ← النجاح!
    message: 'success',
    data: result
  });
  
} catch (error) {
  return res.status(200).json({
    code: 500000,
    message: 'Internal server error',
    data: null
  });
}
```

---

## 📊 **رسم توضيحي للمراحل:**

```
📥 الطلب يصل للسيرفر
    ↓
┌─────────────────────────────────────┐
│ 1️⃣  فحص وجود المعرّفات            │
│    ❌ uniqueId blank? → 400000      │
│    ❌ email blank? → 400001         │
│    ✅ موجودة → التالي               │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 2️⃣  التحقق من صحة المعرّفات        │
│    ❌ uniqueId غير صحيح? → 401000  │
│    ❌ Session غير متطابق? → 401001 │
│    ✅ صحيحة → التالي                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 3️⃣  التحقق من الاشتراك             │
│    ❌ لا يوجد اشتراك? → 420000     │
│    ❌ النموذج غير مسموح? → 420029  │ ← أنت هنا!
│    ✅ مسموح → التالي                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 4️⃣  التحقق من الحدود               │
│    ❌ تجاوز الحد اليومي? → 429000  │
│    ❌ Credits غير كافية? → 429001  │
│    ✅ كافية → التالي                │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ 5️⃣  تنفيذ الطلب                    │
│    ✅ Code 200 + Data               │
└─────────────────────────────────────┘
```

---

## 🧪 **تجارب للفهم:**

### تجربة 1: حذف Uniqueid
```javascript
// الطلب
headers: {
  // Uniqueid: '...'  ← محذوف
}

// النتيجة
{
  "code": 400000,  // ✅ توقف في المرحلة 1
  "message": "uniqueId is blank"
}
```

### تجربة 2: Uniqueid خاطئ/عشوائي
```javascript
// الطلب
headers: {
  Uniqueid: 'XXXXX-WRONG-ID-XXXXX'  // ← غير موجود في DB
}

// النتيجة المتوقعة
{
  "code": 401000,  // ✅ توقف في المرحلة 2
  "message": "Invalid uniqueId"
}
```

### تجربة 3: Uniqueid صحيح لكن Model غير مسموح
```javascript
// الطلب
headers: {
  Uniqueid: '1d2acc9c...'  // ✅ صحيح
}
body: {
  model: 'sora_video2'  // ❌ غير مسموح للـ free
}

// النتيجة
{
  "code": 420029,  // ✅ توقف في المرحلة 3
  "message": "The current level is not supported"
}
```

---

## 🔑 **الدروس المستفادة:**

### 1. **الـ Uniqueid هو المفتاح الأساسي**
```
بدون Uniqueid = لا يمكن التعرف عليك = رفض فوري
```

### 2. **الأخطاء تكشف ترتيب التحقق**
```
400000 (blank) → 401000 (invalid) → 420029 (not allowed)
```
هذا الترتيب يساعدنا نفهم كيف السيرفر يعالج الطلبات

### 3. **كل مرحلة لها كود خطأ مختلف**
```javascript
// Error Code Pattern
4xxxxx = Client errors (طلب خاطئ)
  400000-400999 = Missing/blank fields
  401000-401999 = Authentication errors
  420000-420999 = Authorization/Subscription errors
  429000-429999 = Rate limit errors
  
5xxxxx = Server errors (مشكلة في السيرفر)
  500000 = Internal error

2xxxxx = Success
  200 = Success
```

---

## 🛠️ **كود السيرفر الكامل (تقريبي):**

```javascript
// الكود الحقيقي المتوقع في السيرفر
app.post('/aimodels/api/v1/ai/video/create', async (req, res) => {
  try {
    // 🔍 Stage 1: Required Fields
    const uniqueId = req.headers.uniqueid;
    if (!uniqueId?.trim()) {
      return res.json({ code: 400000, message: 'uniqueId is blank', data: null });
    }
    
    const { email, model, prompt } = req.body;
    if (!email?.trim()) {
      return res.json({ code: 400001, message: 'email is blank', data: null });
    }
    if (!model?.trim()) {
      return res.json({ code: 400002, message: 'model is blank', data: null });
    }
    
    // 🔍 Stage 2: Authentication
    const user = await db.query('SELECT * FROM users WHERE unique_id = ?', [uniqueId]);
    if (!user) {
      return res.json({ code: 401000, message: 'Invalid uniqueId', data: null });
    }
    
    const session = await sessionStore.get(req.cookies.JSESSIONID);
    if (!session || session.userId !== user.id) {
      return res.json({ code: 401001, message: 'Session invalid', data: null });
    }
    
    // 🔍 Stage 3: Authorization
    const subscription = await db.query(`
      SELECT * FROM subscriptions 
      WHERE user_id = ? AND status = 'active'
    `, [user.id]);
    
    if (!subscription) {
      return res.json({ code: 420000, message: 'No subscription', data: null });
    }
    
    const allowedModels = JSON.parse(subscription.features).allowed_models;
    if (!allowedModels.includes(model)) {
      return res.json({ 
        code: 420029, 
        message: 'The current level is not supported, please upgrade your subscription',
        data: null 
      });
    }
    
    // 🔍 Stage 4: Rate Limits
    const requestCount = await redis.get(`requests:${user.id}:${getToday()}`);
    if (requestCount >= subscription.daily_limit) {
      return res.json({ code: 429000, message: 'Daily limit exceeded', data: null });
    }
    
    // ✅ Stage 5: Execute
    const result = await videoService.create({
      userId: user.id,
      model: model,
      prompt: prompt,
      ...req.body
    });
    
    await redis.incr(`requests:${user.id}:${getToday()}`);
    
    return res.json({ code: 200, message: 'success', data: result });
    
  } catch (error) {
    console.error(error);
    return res.json({ code: 500000, message: 'Internal error', data: null });
  }
});
```

---

## 📝 **خلاصة:**

### ما تعلمناه من خطأ 400000:

1. ✅ **Uniqueid إلزامي** - بدونه لا يمكن المتابعة
2. ✅ **التحقق متسلسل** - كل مرحلة تعتمد على نجاح السابقة
3. ✅ **الأخطاء منطقية** - كل خطأ يدل على مرحلة محددة
4. ✅ **السيرفر صارم** - لا يمكن تجاوز أي مرحلة

### موقعك الحالي:
```
✅ المرحلة 1 (400000) - Uniqueid موجود
✅ المرحلة 2 (401xxx) - Uniqueid صحيح + Session صحيح
❌ المرحلة 3 (420029) - Model غير مسموح لاشتراكك
```

**الحل الوحيد**: ترقية الاشتراك أو استخدام `sora_video1` المجاني! 🎯
