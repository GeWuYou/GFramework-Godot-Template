#!/bin/bash

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_FILE="$SCRIPT_DIR/rename_project.config"
cd "$SCRIPT_DIR"
OLD_PROJECT_NAME=""
OLD_NAMESPACE=""
OLD_TEST_NAMESPACE=""
EXCLUDE_DIRS=""
CONTENT_PATTERNS=""
SELF_CLEAN_FILES=""

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "错误: 找不到配置文件: $CONFIG_FILE"
        exit 1
    fi

    local key
    local section=""
    local value
    while IFS='=' read -r key value || [ -n "$key" ]; do
        key="${key//$'\r'/}"
        value="${value//$'\r'/}"
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        if [ -z "$key" ] || [[ "$key" =~ ^# ]]; then
            continue
        fi

        if [[ "$key" =~ ^\[(.*)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        case "$section.$key" in
            template.old_project_name) OLD_PROJECT_NAME="$value" ;;
            template.old_namespace) OLD_NAMESPACE="$value" ;;
            template.old_test_namespace) OLD_TEST_NAMESPACE="$value" ;;
            scan.exclude_dirs) EXCLUDE_DIRS="$value" ;;
            scan.content_patterns) CONTENT_PATTERNS="$value" ;;
            cleanup.self_clean_files) SELF_CLEAN_FILES="$value" ;;
        esac
    done < "$CONFIG_FILE"

    if [ -z "$OLD_PROJECT_NAME" ] || [ -z "$OLD_NAMESPACE" ] || [ -z "$OLD_TEST_NAMESPACE" ] || [ -z "$EXCLUDE_DIRS" ] || [ -z "$CONTENT_PATTERNS" ] || [ -z "$SELF_CLEAN_FILES" ]; then
        echo "错误: 配置文件缺少必要项"
        exit 1
    fi
}

usage() {
    cat << EOF
用法: $0 <新项目名> [选项]

选项:
    -h, --help              显示帮助信息
    --what-if               预览模式，不实际执行更改
    --remove-rename-tools   重命名后删除重命名脚本和共享配置

示例:
    $0 "MyAwesomeGame"
    $0 "MyAwesomeGame" --what-if
    $0 "MyAwesomeGame" --remove-rename-tools
EOF
}

convert_to_pascal_case() {
    local name="$1"
    local cleaned=$(echo "$name" | sed 's/[^a-zA-Z0-9]//g')
    if [ -z "$cleaned" ]; then
        echo ""
        return
    fi
    local first=$(echo "$cleaned" | head -c 1 | tr '[:lower:]' '[:upper:]')
    local rest=$(echo "$cleaned" | tail -c +2)
    echo "${first}${rest}"
}

test_project_name() {
    local name="$1"
    
    if [[ "$name" =~ [^a-zA-Z0-9\-] ]]; then
        echo "错误: 项目名只能包含字母、数字和连字符"
        return 1
    fi
    
    if [[ "$name" =~ ^[0-9] ]]; then
        echo "错误: 项目名不能以数字开头"
        return 1
    fi
    
    if [ ${#name} -lt 2 ] || [ ${#name} -gt 50 ]; then
        echo "错误: 项目名长度必须在 2-50 字符之间"
        return 1
    fi
    
    return 0
}

get_exclude_dirs() {
    local dirs=()
    IFS=',' read -r -a dirs <<< "$EXCLUDE_DIRS"
    printf '%s\n' "${dirs[@]}"
}

should_exclude_path() {
    local file_path="${1#./}"
    local exclude_dir
    local path_part

    for exclude_dir in $(get_exclude_dirs); do
        IFS='/' read -ra path_parts <<< "$file_path"
        for path_part in "${path_parts[@]}"; do
            if [ "$path_part" = "$exclude_dir" ]; then
                return 0
            fi
        done
    done

    return 1
}

find_content_files() {
    local patterns=()
    local find_args=(. -type f '(')
    local first_pattern="true"
    local pattern

    IFS=',' read -r -a patterns <<< "$CONTENT_PATTERNS"
    for pattern in "${patterns[@]}"; do
        if [ -z "$pattern" ]; then
            continue
        fi

        if [ "$first_pattern" = "true" ]; then
            first_pattern="false"
        else
            find_args+=(-o)
        fi

        find_args+=(-name "$pattern")
    done

    find_args+=(')')
    find "${find_args[@]}" 2>/dev/null
}

update_file_content() {
    local file="$1"
    local old_name="$2"
    local new_name="$3"
    local old_ns="$4"
    local new_ns="$5"
    local old_test_ns="$6"
    local new_test_ns="$7"
    local what_if="$8"
    
    if [ "$what_if" = "true" ]; then
        if grep -q "$old_name" "$file" 2>/dev/null || grep -q "$old_ns" "$file" 2>/dev/null || grep -q "$old_test_ns" "$file" 2>/dev/null; then
            echo "  [更新] $file"
        fi
    else
        perl -i.bak -pe "s/\Q${old_test_ns}\E/${new_test_ns}/g; s/\Q${old_name}\E/${new_name}/g; s/\Q${old_ns}\E/${new_ns}/g" "$file"
        rm -f "${file}.bak"
    fi
}

rename_project_path() {
    local source_path="$1"
    local old_name="$2"
    local new_name="$3"
    local what_if="$4"
    
    if [ ! -e "$source_path" ]; then
        return
    fi
    
    local new_path="${source_path//$old_name/$new_name}"
    
    if [ "$what_if" = "true" ]; then
        echo "  [重命名] $source_path -> $new_path"
    else
        if [ -e "$new_path" ]; then
            echo "错误: 目标路径已存在: $new_path"
            exit 1
        fi

        mv "$source_path" "$new_path"
        echo "  [重命名] $new_path"
    fi
}

remove_rename_tools() {
    local cleanup_files=()
    local cleanup_file
    local cleanup_path

    echo ""
    echo "3. 清理重命名工具..."

    IFS=',' read -r -a cleanup_files <<< "$SELF_CLEAN_FILES"
    for cleanup_file in "${cleanup_files[@]}"; do
        if [ -z "$cleanup_file" ]; then
            continue
        fi

        cleanup_path="$SCRIPT_DIR/$cleanup_file"
        if [ "$WHAT_IF" = "true" ]; then
            echo "  [删除] $cleanup_file"
        elif [ -e "$cleanup_path" ]; then
            rm -f "$cleanup_path"
            echo "  [删除] $cleanup_file"
        fi
    done
}

# 参数解析
NEW_PROJECT_NAME=""
WHAT_IF="false"
REMOVE_RENAME_TOOLS="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --what-if)
            WHAT_IF="true"
            shift
            ;;
        --remove-rename-tools)
            REMOVE_RENAME_TOOLS="true"
            shift
            ;;
        -*)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$NEW_PROJECT_NAME" ]; then
                NEW_PROJECT_NAME="$1"
            else
                echo "错误: 只能指定一个项目名"
                exit 1
            fi
            shift
            ;;
    esac
done

load_config

if [ -z "$NEW_PROJECT_NAME" ]; then
    echo "错误: 请指定新项目名"
    usage
    exit 1
fi

echo ""
echo "===== 项目重命名工具 ====="
echo -e "旧项目名: \033[33m$OLD_PROJECT_NAME\033[0m"
echo -e "新项目名: \033[32m$NEW_PROJECT_NAME\033[0m"

if ! test_project_name "$NEW_PROJECT_NAME"; then
    exit 1
fi

NEW_NAMESPACE=$(convert_to_pascal_case "$NEW_PROJECT_NAME")
NEW_TEST_NAMESPACE="${NEW_NAMESPACE}.Tests"
echo -e "新命名空间: \033[32m$NEW_NAMESPACE\033[0m"

echo ""
echo "开始处理..."
if [ "$WHAT_IF" = "true" ]; then
    echo -e "\033[33m[预览模式] 不会实际修改文件\033[0m"
fi

echo ""
echo "1. 更新文件内容..."

processed_files=0

while IFS= read -r file; do
    if should_exclude_path "$file"; then
        continue
    fi
    
    has_changes=false
    if grep -q "$OLD_PROJECT_NAME" "$file" 2>/dev/null || grep -q "$OLD_NAMESPACE" "$file" 2>/dev/null || grep -q "$OLD_TEST_NAMESPACE" "$file" 2>/dev/null; then
        has_changes=true
    fi
    
    if [ "$has_changes" = "true" ]; then
        rel_path="${file#./}"
        
        if [ "$WHAT_IF" = "true" ]; then
            echo -e "  \033[36m[更新]\033[0m $rel_path"
        else
            update_file_content "$file" "$OLD_PROJECT_NAME" "$NEW_PROJECT_NAME" "$OLD_NAMESPACE" "$NEW_NAMESPACE" "$OLD_TEST_NAMESPACE" "$NEW_TEST_NAMESPACE" "$WHAT_IF"
            echo -e "  \033[32m[更新]\033[0m $rel_path"
        fi
        ((processed_files+=1))
    fi
done < <(find_content_files)

echo ""
echo "2. 重命名项目文件..."

rename_project_path "$OLD_PROJECT_NAME.csproj" "$OLD_PROJECT_NAME" "$NEW_PROJECT_NAME" "$WHAT_IF"
rename_project_path "$OLD_PROJECT_NAME.sln" "$OLD_PROJECT_NAME" "$NEW_PROJECT_NAME" "$WHAT_IF"

OLD_TEST_PROJECT_NAME="${OLD_PROJECT_NAME}.Tests"
NEW_TEST_PROJECT_NAME="${NEW_PROJECT_NAME}.Tests"
OLD_TEST_PROJECT_DIR="tests/$OLD_TEST_PROJECT_NAME"

rename_project_path "$OLD_TEST_PROJECT_DIR/$OLD_TEST_PROJECT_NAME.csproj" "$OLD_TEST_PROJECT_NAME.csproj" "$NEW_TEST_PROJECT_NAME.csproj" "$WHAT_IF"
rename_project_path "$OLD_TEST_PROJECT_DIR" "$OLD_TEST_PROJECT_NAME" "$NEW_TEST_PROJECT_NAME" "$WHAT_IF"

if [ -f "$OLD_PROJECT_NAME.sln.DotSettings.user" ]; then
    rename_project_path "$OLD_PROJECT_NAME.sln.DotSettings.user" "$OLD_PROJECT_NAME" "$NEW_PROJECT_NAME" "$WHAT_IF"
fi

if [ "$REMOVE_RENAME_TOOLS" = "true" ]; then
    remove_rename_tools
fi

echo ""
echo "===== 完成 ====="
echo -e "更新文件数: \033[32m$processed_files\033[0m"

if [ "$WHAT_IF" = "false" ]; then
    echo ""
    echo "提示:"
    echo "1. 在 Rider 中重新打开解决方案"
    echo "2. 运行清理命令: dotnet clean"
    echo "3. 重新构建项目: dotnet build"
fi
