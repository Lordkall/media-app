with open('backend/frontend/main.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Find the if __name__ block and replace
new_lines = []
i = 0
while i < len(lines):
    line = lines[i]
    if line.strip() == 'if __name__ == "__main__":':
        new_lines.append('if __name__ == "__main__":\n')
        new_lines.append('    ft.app(target=main, assets_dir="assets")\n')
        # Skip until end
        i += 1
        while i < len(lines):
            i += 1
        break
    else:
        new_lines.append(line)
    i += 1

with open('backend/frontend/main.py', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Done - last 5 lines:")
print(''.join(new_lines[-5:]))
