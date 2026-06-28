import re

home_file = r'd:\carelink-care-link\lib\features\patient\screens\patient_home_screen.dart'

with open(home_file, 'r', encoding='utf-8') as f:
    content = f.read()

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

# Replace EdgeInsets.only(left: .../right: ...) with EdgeInsetsDirectional.only(start: .../end: ...)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)left:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}start: {m.group(2)}{m.group(3)})', content)
content = re.sub(r'EdgeInsets\.only\(([^)]*?)right:\s*([^,)]+)([^)]*?)\)', lambda m: f'EdgeInsetsDirectional.only({m.group(1)}end: {m.group(2)}{m.group(3)})', content)

# Fix Positioned -> PositionedDirectional
content = re.sub(r'Positioned\(\s*bottom:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  bottom: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*bottom:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  bottom: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*top:\s*([^,]+),\s*right:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  top: {m.group(1)},\n  end: {m.group(2)},', content)
content = re.sub(r'Positioned\(\s*right:\s*([^,]+),\s*top:\s*([^,]+),', lambda m: f'PositionedDirectional(\n  end: {m.group(1)},\n  top: {m.group(2)},', content)

# Carefully replace Colors.white inside BoxDecoration
content = re.sub(r'(BoxDecoration\s*\([^)]*)color:\s*Colors\.white([^)]*\))', r'\1color: _p.surface\2', content)

# Replace specific background white containers
content = re.sub(r'(Container\s*\([^)]*)color:\s*Colors\.white([^)]*\))', r'\1color: _p.surface\2', content)

# Fix specific Color(0xFFF8FCFB) or plain backgrounds
content = content.replace('Color(0xFFF8FCFB)', '_p.pageBg')
content = content.replace('Color(0xFFF8FAFA)', '_p.pageBg')

# Replace black/slate text colors
content = content.replace('color: Color(0xFF0F172A)', 'color: _p.inkDark')
content = content.replace('color: const Color(0xFF0F172A)', 'color: _p.inkDark')
content = content.replace('color: Color(0xFF64748B)', 'color: _p.inkMuted')
content = content.replace('color: const Color(0xFF64748B)', 'color: _p.inkMuted')

with open(home_file, 'w', encoding='utf-8') as f:
    f.write(content)
print("Layout v3 fixed")
