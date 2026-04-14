#!/usr/bin/env python3
# 只拦截「删除项目外文件」，允许读写操作项目外文件
import json, sys, os, re

data = json.load(sys.stdin)
cmd  = data.get('tool_input', {}).get('command', '')
proj = os.environ.get('CLAUDE_PROJECT_DIR', os.getcwd())

# 匹配删除命令
DELETE_PATTERNS = [
    r'\brm\b',        # rm / rm -rf
    r'\brmdir\b',
    r'\bdel\b',       # Windows
    r'\brd\b',
    r'\bshred\b',
]

is_delete = any(re.search(p, cmd) for p in DELETE_PATTERNS)

if not is_delete:
    sys.exit(0)  # 非删除命令，直接放行

# 是删除命令 → 检查路径是否在项目内
# 提取命令中所有路径参数（简单启发式）
tokens = cmd.split()
outside = []
for tok in tokens:
    if tok.startswith('-'):
        continue
    if tok in ('rm','rmdir','del','rd','shred'):
        continue
    abs_tok = os.path.abspath(os.path.join(os.getcwd(), tok))
    if not abs_tok.startswith(os.path.abspath(proj)):
        outside.append(tok)

if outside:
    print(
        f"[安全拦截] 禁止删除项目目录外的文件: {outside}\n"
        f"项目根目录: {proj}\n"
        f"如需删除请手动执行。",
        file=sys.stderr
    )
    sys.exit(2)  # exit 2 = 硬拦截

sys.exit(0)  # 路径在项目内，允许
