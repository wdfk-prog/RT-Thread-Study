#
# 脚本功能：在 Git 仓库中重构 Markdown 文档。
# 1. 使用 'git mv' 重命名 .md 文件，以移除文件名前的数字前缀。
#    例如："40 littlefs.md" -> "littlefs.md"
# 2. 修改 .md 文件内容，以移除 Markdown 标题中的数字前缀。
#    例如："## 36.1 初始化" -> "## 初始化"
#
# ======================== 重要提示 ========================
# - 请从你的 Git 仓库的根目录运行此脚本。
# - 运行前，请确保 'git.exe' 已经位于系统的 PATH 环境变量中。
# - 强烈建议在运行前提交所有当前更改，以防万一。
# ==========================================================

# --- 运行前检查 ---
# 检查 'git' 命令是否存在
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "错误: 'git' 命令未找到。请确保 Git 已安装并且在系统的 PATH 环境变量中。" -ForegroundColor Red
    exit
}

# 检查当前目录是否为 Git 仓库
if (-not (Test-Path -Path ".git")) {
    Write-Host "错误: 当前目录不是一个 Git 仓库的根目录。请切换到项目根目录再运行。" -ForegroundColor Red
    exit
}

Write-Host "环境检查通过，准备开始执行脚本..." -ForegroundColor Yellow

# --- 第一步：使用 'git mv' 重命名 .md 文件 ---
Write-Host "`n--- 阶段 1: 使用 'git mv' 重命名文件 ---"

# 获取所有需要重命名的文件列表
# 将其存储在数组中，以避免在循环中修改集合导致的问题
$filesToRename = Get-ChildItem -Path (Get-Location) -Filter "*.md" -Recurse

foreach ($file in $filesToRename) {
    # 使用正则表达式匹配并移除文件名前的 "数字+可选的点+可选的空格"
    $newName = $file.Name -replace "^\d+\s*\.?\s*", ""
    
    if ($file.Name -ne $newName) {
        $newFullName = Join-Path -Path $file.DirectoryName -ChildPath $newName
        try {
            # 执行 git mv 命令。-f 参数可以避免在大小写不敏感的系统上出现问题。
            git mv -f $file.FullName $newFullName
            Write-Host ("[Git MV] " + $file.Name + "  ->  " + $newName) -ForegroundColor Green
        } catch {
            Write-Host ("[Git MV 失败] " + $file.Name + ". 错误: " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

# --- 第二步：修改 .md 文件内容 ---
Write-Host "`n--- 阶段 2: 修改文件内容 ---"
# 再次递归获取所有 .md 文件 (因为文件名已经改变)
Get-ChildItem -Path (Get-Location) -Filter "*.md" -Recurse | ForEach-Object {
    $file = $_
    # 读取文件原始内容
    $originalContent = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    
    # 使用正则表达式替换 Markdown 标题中的编号
    # (?m)          - 多行模式, 使 ^ 匹配每行的开头
    # ^(#{1,6}\s+) - 捕获组1: 匹配并捕获行首的 '#' (1到6个) 和后面的空格
    # \d+(\.\d+)*  - 匹配像 "36" 或 "36.1" 这样的数字
    # \s*\.?\s*    - 匹配后面的可选空格、可选的点和可选的空格
    $newContent = $originalContent -replace '(?m)^(#{1,6}\s+)\d+(\.\d+)*\s*\.?\s*', '$1'
    
    # 如果内容有变化，则使用 UTF-8 编码写回文件
    if ($originalContent -ne $newContent) {
        try {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
            Write-Host ("[内容已修改] " + $file.FullName) -ForegroundColor Cyan
        } catch {
             Write-Host ("[内容修改失败] " + $file.FullName + ". 错误: " + $_.Exception.Message) -ForegroundColor Red
        }
    }
}

Write-Host "`n脚本执行完毕！" -ForegroundColor Yellow
Write-Host "请运行 'git status' 查看所有更改。您可以使用 'git diff' 来对比具体的修改点。" -ForegroundColor Yellow