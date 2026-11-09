# ميزان الأسماك — تطبيق Flutter

تطبيق عربي لإدخال أوزان الأسماك وتصنيف كل نوع في أعمدة من عشرة أوزان، مع جمع تلقائي وحفظ محلي وتصدير PDF والطباعة.

## بناء APK
يبدأ GitHub Actions تلقائياً عند الدفع إلى main، أو يدوياً من تبويب Actions ثم Build Mizan Al Asmak APK ثم Run workflow.
بعد نجاح التشغيل، نزّل Artifact باسم mizan-alasmak-release-apk، ثم فك ضغطه لتحصل على app-release.apk.

## إعدادات البناء
- Flutter 3.24.5 و Java 17
- applicationId: com.alshaheen.mizan_alasmak
- PDF Arabic font: Noto Sans Arabic (يُنزّل وقت البناء)
