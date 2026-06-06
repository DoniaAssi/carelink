#!/usr/bin/env python3
"""
Applies all remaining redesign patches to patient_home_screen.dart.
Run from the project root: python tools/patch_home.py
"""
import sys

path = r'lib/features/patient/screens/patient_home_screen.dart'

with open(path, 'rb') as f:
    content = f.read().decode('utf-8')

original = content
changes_done = []

def apply(name, old, new):
    global content
    if old not in content:
        print(f'WARN [{name}]: target not found — skipping')
        return False
    count = content.count(old)
    if count > 1:
        print(f'WARN [{name}]: {count} occurrences found — replacing first only')
    content = content.replace(old, new, 1)
    changes_done.append(name)
    return True

# ============================================================
# CHANGE 4: Fix AI Provider Card — use real provider image
# Replace hardcoded Image.asset('assets/images/doctorportrait.jpg') 
# in _buildAiProviderCard with profileAvatarOrPlaceholder
# ============================================================
OLD4 = (
    '          Row(\r\n'
    '            children: [\r\n'
    '              ClipOval(\r\n'
    '                child: Image.asset(\r\n'
    "                  'assets/images/doctorportrait.jpg',\r\n"
    '                  width: 54,\r\n'
    '                  height: 54,\r\n'
    '                  fit: BoxFit.cover,\r\n'
    '                  errorBuilder: (ctx, e, _) => Container(\r\n'
    '                    width: 54,\r\n'
    '                    height: 54,\r\n'
    '                    color: AppColors.primary.withValues(alpha: 0.10),\r\n'
    '                    child: const Icon(Icons.person_rounded,\r\n'
    '                        color: AppColors.primary, size: 28),\r\n'
    '                  ),\r\n'
    '                ),\r\n'
    '              ),\r\n'
    '              const SizedBox(width: 12),\r\n'
    '              Expanded(\r\n'
    '                child: Column(\r\n'
    '                  crossAxisAlignment: CrossAxisAlignment.start,\r\n'
    '                  children: [\r\n'
    '                    Text(\r\n'
    '                      name,'
)
NEW4 = (
    '          Row(\r\n'
    '            children: [\r\n'
    '              ClipOval(\r\n'
    '                child: SizedBox(\r\n'
    '                  width: 54,\r\n'
    '                  height: 54,\r\n'
    '                  child: profileAvatarOrPlaceholder(\r\n'
    '                    imageUrl: profileImageUrlFromMap(\r\n'
    '                      (rec?[\'provider\'] is Map\r\n'
    '                          ? Map<String, dynamic>.from(rec![\'provider\'] as Map)\r\n'
    '                          : rec) ?? {},\r\n'
    '                    ),\r\n'
    '                    size: 54,\r\n'
    '                    placeholderColor: AppColors.primary,\r\n'
    '                    placeholderIcon: Icons.person_rounded,\r\n'
    '                    iconSize: 28,\r\n'
    '                  ),\r\n'
    '                ),\r\n'
    '              ),\r\n'
    '              const SizedBox(width: 12),\r\n'
    '              Expanded(\r\n'
    '                child: Column(\r\n'
    '                  crossAxisAlignment: CrossAxisAlignment.start,\r\n'
    '                  children: [\r\n'
    '                    Text(\r\n'
    '                      name,'
)
apply('4: AI card real provider image', OLD4, NEW4)

# ============================================================
# CHANGE 5: Add "Upload Record" button to AI card empty state
# ============================================================
OLD5 = (
    '          if (reasons.isEmpty && !hasMed) ...[\r\n'
    '            const SizedBox(height: 10),\r\n'
    '            Text(\r\n'
    '              _homeText(\r\n'
    "                'Upload a medical report to unlock personalised recommendations.',\r\n"
    "                'ارفع تقريراً طبياً للحصول على توصيات مخصصة.',\r\n"
    '              ),\r\n'
    '              maxLines: 2,\r\n'
    '              style: TextStyle(\r\n'
    '                color: _p.inkMuted,\r\n'
    '                fontSize: 12,\r\n'
    '                fontWeight: FontWeight.w600,\r\n'
    '                height: 1.3,\r\n'
    '              ),\r\n'
    '            ),\r\n'
    '          ],'
)
NEW5 = (
    '          if (reasons.isEmpty && !hasMed) ...[\r\n'
    '            const SizedBox(height: 10),\r\n'
    '            Text(\r\n'
    '              _homeText(\r\n'
    "                'Upload a medical report to unlock personalised recommendations.',\r\n"
    "                'ارفع تقريراً طبياً للحصول على توصيات مخصصة.',\r\n"
    '              ),\r\n'
    '              maxLines: 2,\r\n'
    '              style: TextStyle(\r\n'
    '                color: _p.inkMuted,\r\n'
    '                fontSize: 12,\r\n'
    '                fontWeight: FontWeight.w600,\r\n'
    '                height: 1.3,\r\n'
    '              ),\r\n'
    '            ),\r\n'
    '            const SizedBox(height: 10),\r\n'
    '            SizedBox(\r\n'
    '              width: double.infinity,\r\n'
    '              height: 36,\r\n'
    '              child: OutlinedButton.icon(\r\n'
    '                onPressed: _openMedicalRecords,\r\n'
    '                icon: const Icon(Icons.upload_file_outlined, size: 16),\r\n'
    '                label: Text(\r\n'
    "                  _homeText('Upload Record', 'رفع سجل'),\r\n"
    '                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),\r\n'
    '                ),\r\n'
    '                style: OutlinedButton.styleFrom(\r\n'
    '                  foregroundColor: AppColors.primary,\r\n'
    '                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.55)),\r\n'
    '                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),\r\n'
    '                  padding: const EdgeInsets.symmetric(horizontal: 14),\r\n'
    '                ),\r\n'
    '              ),\r\n'
    '            ),\r\n'
    '          ],'
)
apply('5: Upload Record CTA in AI card empty state', OLD5, NEW5)

# ============================================================
# CHANGE 6: Remove double-card decoration from notifications preview
# ============================================================
OLD6 = (
    "  Widget _buildNotificationsPreview() {\r\n"
    "    if (_latestNotifications.isEmpty) return const SizedBox.shrink();\r\n"
    "    final items = _latestNotifications.take(3).toList();\r\n"
    "    return Padding(\r\n"
    "      padding: const EdgeInsets.symmetric(horizontal: 16),\r\n"
    "      child: Container(\r\n"
    "        padding: const EdgeInsets.all(14),\r\n"
    "        decoration: _homeCardDecoration(),\r\n"
    "        child: Column(\r\n"
    "          crossAxisAlignment: CrossAxisAlignment.stretch,\r\n"
    "          children: [\r\n"
    "            _buildSectionHeader(\r\n"
    "              title: _homeText('Notifications', '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a'),\r\n"
    "              actionText: _homeText('View all', '\u0639\u0631\u0636 \u0627\u0644\u0643\u0644'),\r\n"
    "              onActionTap: _openNotifications,\r\n"
    "            ),\r\n"
    "            const SizedBox(height: 10),\r\n"
    "            for (int i = 0; i < items.length; i++) ...[\r\n"
    "              if (i > 0) const SizedBox(height: 10),\r\n"
    "              _buildNotificationRow(items[i]),\r\n"
    "            ],\r\n"
    "          ],\r\n"
    "        ),\r\n"
    "      ),\r\n"
    "    );\r\n"
    "  }\r\n"
)
NEW6 = (
    "  Widget _buildNotificationsPreview() {\r\n"
    "    if (_latestNotifications.isEmpty) return const SizedBox.shrink();\r\n"
    "    final items = _latestNotifications.take(3).toList();\r\n"
    "    return Padding(\r\n"
    "      padding: const EdgeInsets.symmetric(horizontal: 16),\r\n"
    "      child: Column(\r\n"
    "        crossAxisAlignment: CrossAxisAlignment.stretch,\r\n"
    "        children: [\r\n"
    "          _buildSectionHeader(\r\n"
    "            title: _homeText('Notifications', '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a'),\r\n"
    "            actionText: _homeText('View all', '\u0639\u0631\u0636 \u0627\u0644\u0643\u0644'),\r\n"
    "            onActionTap: _openNotifications,\r\n"
    "          ),\r\n"
    "          const SizedBox(height: 10),\r\n"
    "          Container(\r\n"
    "            padding: const EdgeInsets.all(14),\r\n"
    "            decoration: BoxDecoration(\r\n"
    "              color: _p.surface,\r\n"
    "              borderRadius: BorderRadius.circular(16),\r\n"
    "              border: Border.all(color: _p.stroke),\r\n"
    "            ),\r\n"
    "            child: Column(\r\n"
    "              crossAxisAlignment: CrossAxisAlignment.stretch,\r\n"
    "              children: [\r\n"
    "                for (int i = 0; i < items.length; i++) ...[\r\n"
    "                  if (i > 0) Padding(\r\n"
    "                    padding: const EdgeInsets.only(top: 10),\r\n"
    "                    child: Divider(height: 1, color: _p.stroke),\r\n"
    "                  ),\r\n"
    "                  if (i > 0) const SizedBox(height: 10),\r\n"
    "                  _buildNotificationRow(items[i]),\r\n"
    "                ],\r\n"
    "              ],\r\n"
    "            ),\r\n"
    "          ),\r\n"
    "        ],\r\n"
    "      ),\r\n"
    "    );\r\n"
    "  }\r\n"
)
apply('6: Notifications - remove double card, add dividers', OLD6, NEW6)

# ============================================================
# CHANGE 7: Replace wide favorites cards with compact avatar bubbles
# ============================================================
OLD7 = (
    "  Widget _buildFavoritesRow() {\r\n"
    "    final list = _myFavorites.take(5).toList();\r\n"
    "    return SizedBox(\r\n"
    "      height: 100,\r\n"
    "      child: ListView.separated(\r\n"
    "        scrollDirection: Axis.horizontal,\r\n"
    "        padding: const EdgeInsets.symmetric(horizontal: 16),\r\n"
    "        itemCount: list.length,\r\n"
    "        separatorBuilder: (_, _) => const SizedBox(width: 10),\r\n"
    "        itemBuilder: (context, index) {\r\n"
    "          final p = list[index];\r\n"
    "          final providerId = p['providerId'] ?? '';\r\n"
    "          final name = p['displayName'] ?? '';\r\n"
    "          final specialty = p['specialty'] ?? '';\r\n"
    "          final imageUrl = p['profilePictureUrl'];\r\n"
    "\r\n"
    "          return Material(\r\n"
    "            color: Colors.transparent,\r\n"
    "            child: InkWell(\r\n"
    "              borderRadius: BorderRadius.circular(16),\r\n"
    "              onTap: () {\r\n"
    "                Navigator.push(\r\n"
    "                  context,\r\n"
    "                  MaterialPageRoute(\r\n"
    "                    builder: (_) => ProviderDetailsScreen(\r\n"
    "                      provider: ProviderModel(\r\n"
    "                        userId: providerId,\r\n"
    "                        fullName: name,\r\n"
    "                        specialization: specialty,\r\n"
    "                        serviceType: '',\r\n"
    "                        overallRating: 0.0,\r\n"
    "                        role: 'doctor',\r\n"
    "                        isAvailable: true,\r\n"
    "                      ),\r\n"
    "                      patientUserId: widget.userId ?? '',\r\n"
    "                    ),\r\n"
    "                  ),\r\n"
    "                ).then((_) => _loadFavorites());\r\n"
    "              },\r\n"
    "              child: Container(\r\n"
    "                width: 200,\r\n"
    "                padding: const EdgeInsets.symmetric(\r\n"
    "                  horizontal: 12,\r\n"
    "                  vertical: 10,\r\n"
    "                ),\r\n"
    "                decoration: BoxDecoration(\r\n"
    "                  color: _p.surface,\r\n"
    "                  borderRadius: BorderRadius.circular(18),\r\n"
    "                  border: Border.all(color: _p.stroke),\r\n"
    "                  boxShadow: [\r\n"
    "                    BoxShadow(\r\n"
    "                      color: Colors.black.withValues(alpha: 0.04),\r\n"
    "                      blurRadius: 12,\r\n"
    "                      offset: const Offset(0, 4),\r\n"
    "                    ),\r\n"
    "                  ],\r\n"
    "                ),\r\n"
    "                child: Row(\r\n"
    "                  children: [\r\n"
    "                    CircleAvatar(\r\n"
    "                      radius: 24,\r\n"
    "                      backgroundColor: AppColors.primary.withValues(\r\n"
    "                        alpha: 0.12,\r\n"
    "                      ),\r\n"
    "                      backgroundImage:\r\n"
    "                          imageUrl != null && imageUrl.toString().isNotEmpty\r\n"
    "                          ? NetworkImage(imageUrl)\r\n"
    "                          : null,\r\n"
    "                      child: imageUrl == null || imageUrl.toString().isEmpty\r\n"
    "                          ? const Icon(\r\n"
    "                              Icons.medical_services_rounded,\r\n"
    "                              color: AppColors.primary,\r\n"
    "                              size: 26,\r\n"
    "                            )\r\n"
    "                          : null,\r\n"
    "                    ),\r\n"
    "                    const SizedBox(width: 10),\r\n"
    "                    Expanded(\r\n"
    "                      child: Column(\r\n"
    "                        mainAxisAlignment: MainAxisAlignment.center,\r\n"
    "                        crossAxisAlignment: CrossAxisAlignment.start,\r\n"
    "                        children: [\r\n"
    "                          Text(\r\n"
    "                            name,\r\n"
    "                            maxLines: 1,\r\n"
    "                            overflow: TextOverflow.ellipsis,\r\n"
    "                            style: TextStyle(\r\n"
    "                              fontWeight: FontWeight.w800,\r\n"
    "                              fontSize: 14,\r\n"
    "                              color: _p.inkDark,\r\n"
    "                            ),\r\n"
    "                          ),\r\n"
    "                          const SizedBox(height: 2),\r\n"
    "                          Text(\r\n"
    "                            specialty.trim().isEmpty\r\n"
    "                                ? 'Care provider'\r\n"
    "                                : specialty,\r\n"
    "                            maxLines: 1,\r\n"
    "                            overflow: TextOverflow.ellipsis,\r\n"
    "                            style: TextStyle(fontSize: 12, color: _p.inkMuted),\r\n"
    "                          ),\r\n"
    "                        ],\r\n"
    "                      ),\r\n"
    "                    ),\r\n"
    "                    const Icon(\r\n"
    "                      Icons.favorite_rounded,\r\n"
    "                      color: Color(0xFFE53935),\r\n"
    "                      size: 18,\r\n"
    "                    ),\r\n"
    "                  ],\r\n"
    "                ),\r\n"
    "              ),\r\n"
    "            ),\r\n"
    "          );\r\n"
    "        },\r\n"
    "      ),\r\n"
    "    );\r\n"
    "  }\r\n"
)
NEW7 = (
    "  /// Compact horizontal avatar+name bubbles for Favorites section.\r\n"
    "  Widget _buildFavoritesRow() {\r\n"
    "    final list = _myFavorites.take(6).toList();\r\n"
    "    return SizedBox(\r\n"
    "      height: 92,\r\n"
    "      child: ListView.separated(\r\n"
    "        scrollDirection: Axis.horizontal,\r\n"
    "        padding: const EdgeInsets.symmetric(horizontal: 16),\r\n"
    "        itemCount: list.length,\r\n"
    "        separatorBuilder: (_, __) => const SizedBox(width: 12),\r\n"
    "        itemBuilder: (context, index) {\r\n"
    "          final p = list[index];\r\n"
    "          final providerId = (p['providerId'] ?? '').toString();\r\n"
    "          final name = (p['displayName'] ?? '').toString();\r\n"
    "          final firstName = name.trim().split(RegExp(r'\\s+')).first;\r\n"
    "          final specialty = (p['specialty'] ?? '').toString();\r\n"
    "          final imageUrl = p['profilePictureUrl']?.toString();\r\n"
    "\r\n"
    "          return GestureDetector(\r\n"
    "            onTap: () {\r\n"
    "              Navigator.push(\r\n"
    "                context,\r\n"
    "                MaterialPageRoute(\r\n"
    "                  builder: (_) => ProviderDetailsScreen(\r\n"
    "                    provider: ProviderModel(\r\n"
    "                      userId: providerId,\r\n"
    "                      fullName: name,\r\n"
    "                      specialization: specialty,\r\n"
    "                      serviceType: '',\r\n"
    "                      overallRating: 0.0,\r\n"
    "                      role: 'doctor',\r\n"
    "                      isAvailable: true,\r\n"
    "                    ),\r\n"
    "                    patientUserId: widget.userId ?? '',\r\n"
    "                  ),\r\n"
    "                ),\r\n"
    "              ).then((_) => _loadFavorites());\r\n"
    "            },\r\n"
    "            child: SizedBox(\r\n"
    "              width: 64,\r\n"
    "              child: Column(\r\n"
    "                mainAxisSize: MainAxisSize.min,\r\n"
    "                children: [\r\n"
    "                  Stack(\r\n"
    "                    clipBehavior: Clip.none,\r\n"
    "                    children: [\r\n"
    "                      Container(\r\n"
    "                        width: 54,\r\n"
    "                        height: 54,\r\n"
    "                        decoration: BoxDecoration(\r\n"
    "                          shape: BoxShape.circle,\r\n"
    "                          color: AppColors.primary.withValues(alpha: 0.10),\r\n"
    "                          border: Border.all(\r\n"
    "                            color: AppColors.primary.withValues(alpha: 0.22),\r\n"
    "                            width: 1.5,\r\n"
    "                          ),\r\n"
    "                        ),\r\n"
    "                        clipBehavior: Clip.antiAlias,\r\n"
    "                        child: profileAvatarOrPlaceholder(\r\n"
    "                          imageUrl: imageUrl,\r\n"
    "                          size: 54,\r\n"
    "                          placeholderColor: AppColors.primary,\r\n"
    "                          placeholderIcon: Icons.medical_services_rounded,\r\n"
    "                          iconSize: 24,\r\n"
    "                        ),\r\n"
    "                      ),\r\n"
    "                      Positioned(\r\n"
    "                        bottom: 0,\r\n"
    "                        right: 0,\r\n"
    "                        child: Container(\r\n"
    "                          width: 16,\r\n"
    "                          height: 16,\r\n"
    "                          decoration: const BoxDecoration(\r\n"
    "                            color: Color(0xFFE53935),\r\n"
    "                            shape: BoxShape.circle,\r\n"
    "                          ),\r\n"
    "                          child: const Icon(\r\n"
    "                            Icons.favorite_rounded,\r\n"
    "                            color: Colors.white,\r\n"
    "                            size: 9,\r\n"
    "                          ),\r\n"
    "                        ),\r\n"
    "                      ),\r\n"
    "                    ],\r\n"
    "                  ),\r\n"
    "                  const SizedBox(height: 6),\r\n"
    "                  Text(\r\n"
    "                    firstName,\r\n"
    "                    maxLines: 1,\r\n"
    "                    overflow: TextOverflow.ellipsis,\r\n"
    "                    textAlign: TextAlign.center,\r\n"
    "                    style: TextStyle(\r\n"
    "                      color: _p.inkDark,\r\n"
    "                      fontSize: 11,\r\n"
    "                      fontWeight: FontWeight.w700,\r\n"
    "                    ),\r\n"
    "                  ),\r\n"
    "                ],\r\n"
    "              ),\r\n"
    "            ),\r\n"
    "          );\r\n"
    "        },\r\n"
    "      ),\r\n"
    "    );\r\n"
    "  }\r\n"
)
apply('7: Favorites - compact avatar bubbles', OLD7, NEW7)

# ============================================================
# CHANGE 8: Quick Actions visual polish - stronger shadows, gradient icon bg
# ============================================================
OLD8 = (
    "                Container(\r\n"
    "                  width: 42,\r\n"
    "                  height: 42,\r\n"
    "                  decoration: BoxDecoration(\r\n"
    "                    color: AppColors.primary.withValues(alpha: 0.12),\r\n"
    "                    borderRadius: BorderRadius.circular(12),\r\n"
    "                  ),\r\n"
    "                  child: Icon(icon, color: AppColors.primary, size: 22),\r\n"
    "                ),\r\n"
    "                const SizedBox(height: 8),\r\n"
    "                Text(\r\n"
    "                  label,\r\n"
    "                  maxLines: 1,\r\n"
    "                  overflow: TextOverflow.ellipsis,\r\n"
    "                  textAlign: TextAlign.center,\r\n"
    "                  style: TextStyle(\r\n"
    "                    color: _p.inkDark,\r\n"
    "                    fontSize: 10.5,\r\n"
    "                    fontWeight: FontWeight.w800,\r\n"
    "                  ),\r\n"
    "                ),"
)
NEW8 = (
    "                Container(\r\n"
    "                  width: 44,\r\n"
    "                  height: 44,\r\n"
    "                  decoration: BoxDecoration(\r\n"
    "                    gradient: LinearGradient(\r\n"
    "                      begin: Alignment.topLeft,\r\n"
    "                      end: Alignment.bottomRight,\r\n"
    "                      colors: [\r\n"
    "                        AppColors.primary.withValues(\r\n"
    "                          alpha: _p.isDark ? 0.22 : 0.15),\r\n"
    "                        AppColors.primary.withValues(\r\n"
    "                          alpha: _p.isDark ? 0.16 : 0.10),\r\n"
    "                      ],\r\n"
    "                    ),\r\n"
    "                    borderRadius: BorderRadius.circular(14),\r\n"
    "                  ),\r\n"
    "                  child: Icon(icon, color: AppColors.primary, size: 22),\r\n"
    "                ),\r\n"
    "                const SizedBox(height: 8),\r\n"
    "                Text(\r\n"
    "                  label,\r\n"
    "                  maxLines: 1,\r\n"
    "                  overflow: TextOverflow.ellipsis,\r\n"
    "                  textAlign: TextAlign.center,\r\n"
    "                  style: TextStyle(\r\n"
    "                    color: _p.inkDark,\r\n"
    "                    fontSize: 10.5,\r\n"
    "                    fontWeight: FontWeight.w800,\r\n"
    "                  ),\r\n"
    "                ),"
)
apply('8: Quick Actions - icon gradient bg', OLD8, NEW8)

# ============================================================
# CHANGE 9: Fix scroll top padding now that AppBar is gone
# Increase top padding from 12 to 16 for better visual breathing room
# ============================================================
OLD9 = "                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 90),"
NEW9 = "                  padding: const EdgeInsets.fromLTRB(0, 16, 0, 90),"
apply('9: Scroll top padding 12->16', OLD9, NEW9)

# ============================================================
# Summary
# ============================================================
print()
print('=== CHANGES APPLIED ===')
for c in changes_done:
    print(f'  [OK] {c}')

if content != original:
    with open(path, 'wb') as f:
        f.write(content.encode('utf-8'))
    print(f'\nFile saved. Total changes: {len(changes_done)}')
else:
    print('\nNo changes were made!')
    sys.exit(1)
