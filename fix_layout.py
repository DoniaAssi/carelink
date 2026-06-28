import re
import os

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix _buildQuickActions InkWell tap interception & Colors.white
quick_action_old = """    Widget quickActionCard(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,"""

quick_action_new = """    final _p = CarelinkPalette.of(context);
    Widget quickActionCard(IconData icon, String label, VoidCallback onTap) {
      return Expanded(
        child: Material(
          color: _p.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: BoxDecoration("""

content = content.replace(quick_action_old, quick_action_new)

# Fix Colors.white in _providerRecommendationCarouselCard
# Assuming there is a container with color: Colors.white
rec_card_old = """      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,"""
          
rec_card_new = """      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CarelinkPalette.of(context).surface,"""

content = content.replace(rec_card_old, rec_card_new)

# Replace all EdgeInsets.only(left: ... / right: ...) with EdgeInsetsDirectional.only(start: ... / end: ...)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)left:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}start: {m.group(2)}{m.group(3)})', content)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)right:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}end: {m.group(2)}{m.group(3)})', content)

# Fix Positioned bottom/right -> PositionedDirectional bottom/end
content = re.sub(r'Positioned\(\s*bottom:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  bottom: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*bottom:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  bottom: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*top:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  top: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*top:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  top: {m.group(2)},', content)

# Fix specific Color(0xFFF8FCFB) or plain backgrounds if used
content = content.replace('Color(0xFFF8FCFB)', 'CarelinkPalette.of(context).pageBg')
content = content.replace('Color(0xFFF8FAFA)', 'CarelinkPalette.of(context).pageBg')

# Fix text colors that shouldn't be hardcoded
content = content.replace('color: Color(0xFF0F172A)', 'color: CarelinkPalette.of(context).inkDark')
content = content.replace('color: const Color(0xFF0F172A)', 'color: CarelinkPalette.of(context).inkDark')
content = content.replace('color: Color(0xFF64748B)', 'color: CarelinkPalette.of(context).inkMuted')
content = content.replace('color: const Color(0xFF64748B)', 'color: CarelinkPalette.of(context).inkMuted')

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(content)
print("Layout fixed")
