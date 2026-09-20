import json
import os
import re

transcript_path = r'C:\Users\ionel\.gemini\antigravity-cli\brain\ac13191e-d267-488f-9048-ccbd1bd1ac81\.system_generated\logs\transcript_full.jsonl'
files_state = {}

def apply_replace(content, target, replacement):
    if target in content:
        return content.replace(target, replacement)
    return content

with open(transcript_path, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            step = json.loads(line)
            
            # 1. Parse Tool Calls (for write_to_file and replace_file_content arguments)
            if 'tool_calls' in step:
                for tc in step['tool_calls']:
                    args = tc.get('arguments', {})
                    name = tc.get('name')
                    
                    if name == 'default_api:write_to_file':
                        target = args.get('TargetFile')
                        code = args.get('CodeContent')
                        if target and code:
                            files_state[target] = code
                            
                    elif name == 'default_api:replace_file_content':
                        target = args.get('TargetFile')
                        target_content = args.get('TargetContent')
                        replacement = args.get('ReplacementContent')
                        if target and target_content and replacement and target in files_state:
                            files_state[target] = apply_replace(files_state[target], target_content, replacement)
                            
            # 2. Parse Tool Responses (for view_file output)
            if 'content' in step and isinstance(step['content'], str) and 'file://' in step['content']:
                # The agent might receive the view_file response
                # Let's check if it's a tool response for view_file
                pass
            
            # Actually, the view_file output is in the system message or tool response content
            # Let's parse the string content directly if it looks like a view_file output
            text = step.get('content', '')
            if isinstance(text, str):
                if 'The following code has been modified to include a line number before every line' in text:
                    # Extract file path
                    path_match = re.search(r'File Path: `file:///(.*?)`', text)
                    if path_match:
                        filepath = path_match.group(1).replace('/', '\\')
                        
                        # Extract the lines
                        lines = []
                        capture = False
                        for line_str in text.split('\n'):
                            if line_str.startswith('The following code has been modified'):
                                capture = True
                                continue
                            if capture:
                                if line_str.startswith('The above content shows'):
                                    break
                                # format is "<line_number>: <original_line>"
                                # match it safely
                                match = re.match(r'^\d+:\s?(.*)', line_str)
                                if match:
                                    lines.append(match.group(1))
                        
                        if lines:
                            files_state[filepath] = '\n'.join(lines)
                            
        except Exception as e:
            pass

# Output everything we recovered
print(f"Recovered {len(files_state)} files.")
for path, content in files_state.items():
    if path.endswith('.dart'):
        print(f"Writing {path}")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as out:
            out.write(content)

print("Done!")
