with open("iOS/Chess3D/Chess3DApp.swift", "r", encoding="utf-8") as f:
    text = f.read()

start_marker = "                highlightNodes.append(markerNode)\n            }\n        }\n        \n            for _ in 0..<10 {"
end_marker = "        func updateCamera(perspective: ChessSceneView.CameraPerspective) {"

# Try CRLF
if "highlightNodes.append(markerNode)\r\n            }\r\n        }\r\n        \r\n            for _ in 0..<10 {" in text:
    start_marker = "                highlightNodes.append(markerNode)\r\n            }\r\n        }\r\n        \r\n            for _ in 0..<10 {"
    end_marker = "        func updateCamera(perspective: ChessSceneView.CameraPerspective) {"

if start_marker in text:
    idx_start = text.find(start_marker) + len("                highlightNodes.append(markerNode)\n            }\n        }\n")
    idx_end = text.find(end_marker)
    if idx_start > 0 and idx_end > idx_start:
        cleaned = text[:idx_start] + "\n        \n" + text[idx_end:]
        with open("iOS/Chess3D/Chess3DApp.swift", "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("Successfully removed duplicate block!")
    else:
        print("Indices not matching:", idx_start, idx_end)
else:
    print("start_marker not found directly, checking substring...")
    start_sub = "for _ in 0..<10 {"
    idx_start = text.find(start_sub)
    idx_end = text.find(end_marker)
    print("Sub indices:", idx_start, idx_end)
    if idx_start > 0 and idx_end > idx_start:
        # Find preceding closing brace
        idx_prev = text.rfind("highlightNodes.append(markerNode)", 0, idx_start)
        idx_brace = text.find("}", idx_prev)
        idx_brace2 = text.find("}", idx_brace + 1)
        cleaned = text[:idx_brace2+1] + "\n        \n" + text[idx_end:]
        with open("iOS/Chess3D/Chess3DApp.swift", "w", encoding="utf-8") as f:
            f.write(cleaned)
        print("Cleaned using sub indices!")
