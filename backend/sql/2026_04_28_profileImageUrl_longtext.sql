-- تخزين صور profile كـ base64 قد يتجاوز حدود TEXT (64KB). استخدم LONGTEXT.
-- نفّذ مرة واحدة إذا كان العمود من نوع TEXT أو أصغر.

ALTER TABLE `user` MODIFY COLUMN `profileImageUrl` LONGTEXT NULL;
