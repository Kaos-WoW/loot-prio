# Simple script to search for "Band of Devastation" and "Unstoppable" in the saved Wowhead HTML to see comments
with open(r"C:\Users\maxim\.gemini\antigravity\brain\49b2b7a8-2d6c-4dc5-9c8b-5d5d508847ac\.system_generated\steps\458\content.md", "r", encoding="utf-8") as f:
    text = f.read()

import re
# Let's search for occurrences and show 200 chars around them
for name in ["Band of Devastation", "Unstoppable Aggressor", "Shapeshifter"]:
    print(f"=== Matches for '{name}' ===")
    for m in re.finditer(re.escape(name), text, re.IGNORECASE):
        start = max(0, m.start() - 150)
        end = min(len(text), m.end() + 250)
        # Strip HTML tags just for display ease
        snippet = re.sub(r'<[^>]+>', ' ', text[start:end])
        print(snippet)
        print("-" * 50)
