import re
import os

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix InkWell hiding ripple behind colored Container
quick_action_old = """    Widget _quickActionCard(IconData icon, String label, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,"""

quick_action_new = """    Widget _quickActionCard(IconData icon, String label, VoidCallback onTap) {
      return Material(
        color: _p.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),"""

content = content.replace(quick_action_old, quick_action_new)

# Replace all EdgeInsets.only(left: ... / right: ...) with EdgeInsetsDirectional.only(start: ... / end: ...)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)left:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}start: {m.group(2)}{m.group(3)})', content)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)right:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}end: {m.group(2)}{m.group(3)})', content)

# Fix Positioned bottom/right -> PositionedDirectional bottom/end
content = re.sub(r'Positioned\(\s*bottom:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  bottom: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*bottom:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  bottom: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*top:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  top: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*top:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  top: {m.group(2)},', content)

# Replace Colors.white with _p.surface in BoxDecoration
content = re.sub(r'color:\s*Colors\.white\s*,', r'color: _p.surface,', content)
content = re.sub(r'backgroundColor:\s*Colors\.white\s*,', r'backgroundColor: _p.surface,', content)

# Fix text colors that shouldn't be hardcoded to black
content = content.replace('color: Color(0xFF0F172A)', 'color: _p.inkDark')
content = content.replace('color: const Color(0xFF0F172A)', 'color: _p.inkDark')
content = content.replace('color: Color(0xFF64748B)', 'color: _p.inkMuted')
content = content.replace('color: const Color(0xFF64748B)', 'color: _p.inkMuted')

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(content)
print("Layout v2 fixed")
