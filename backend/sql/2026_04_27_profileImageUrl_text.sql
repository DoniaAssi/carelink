-- Backend (auth.js / patient.js) يتوقع العمود: user.profileImageUrl
-- لصور base64 الطويلة يُفضّل النوع TEXT.
--
-- إذا ظهرت رسالة: Unknown column 'profileImageUrl' → نفّذ سطر ADD فقط.
-- إذا ظهرت: Duplicate column name → العمول موجود (مرّة ثانية: استخدم MODIFY أدناه).
--
-- 1) إضافة العمول إن لم يكن موجوداً
ALTER TABLE `user`
  ADD COLUMN `profileImageUrl` TEXT NULL;

-- 2) (اختياري) إن كان لديك العمول كـ VARCHAR وتريد توسيعه فقط
--    احذف سطر ADD أعلاه ونفّذ:
-- ALTER TABLE `user` MODIFY COLUMN `profileImageUrl` TEXT NULL;
