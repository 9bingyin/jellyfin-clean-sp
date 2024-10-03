#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函数：检查依赖
check_dependencies() {
    local missing_deps=0
    for cmd in sed grep mktemp stat; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}Error: $cmd is not installed or not in PATH${NC}"
            ((missing_deps++))
        fi
    done
    if [ $missing_deps -gt 0 ]; then
        echo -e "${RED}Please install missing dependencies and try again.${NC}"
        exit 1
    fi
    echo -e "${GREEN}All dependencies are satisfied.${NC}"
}

# 初始化计数器和数组
total_files=0
processed_files=0
skipped_files=0
files_with_airsafter_season=()

# 函数：检查文件是否应该被处理
should_process_file() {
    local filename="$1"
    # 检查文件是否以 .nfo 结尾，且不是 season.nfo
    if [[ "$filename" == *.nfo && "$(basename "$filename")" != "season.nfo" ]]; then
        return 0  # 应该处理
    else
        return 1  # 不应该处理
    fi
}

# 函数：处理单个文件
process_file() {
    local filename="$1"
    if [ ! -f "$filename" ]; then
        echo -e "${RED}File not found: $filename${NC}"
        ((skipped_files++))
        return 1
    fi

    if ! should_process_file "$filename"; then
        echo -e "${YELLOW}Skipping file: $filename (not a valid .nfo file or is season.nfo)${NC}"
        ((skipped_files++))
        return 0
    fi

    echo -e "${GREEN}Processing file: $filename${NC}"
    local changes=0
    local has_airsafter_season=false

    # 获取原始文件的权限
    local original_permissions=$(stat -c %a "$filename")

    # 使用临时文件进行处理
    local tempfile=$(mktemp)
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        case "$line" in
            *"<airsbefore_episode>"*)
                echo -e "${YELLOW}  Removed: <airsbefore_episode>${NC}"
                ((changes++))
                continue
                ;;
            *"<airsbefore_season>"*)
                echo -e "${YELLOW}  Removed: <airsbefore_season>${NC}"
                ((changes++))
                continue
                ;;
            *"<airsafter_season>"*)
                echo -e "${YELLOW}  Removed: <airsafter_season>${NC}"
                has_airsafter_season=true
                ((changes++))
                continue
                ;;
            *"<displayepisode>"*)
                echo -e "${YELLOW}  Removed: <displayepisode>${NC}"
                ((changes++))
                continue
                ;;
            *"<displayseason>"*)
                echo -e "${YELLOW}  Replaced: <displayseason> with <displayseason>0</displayseason>${NC}"
                echo "  <displayseason>0</displayseason>" >> "$tempfile"
                ((changes++))
                continue
                ;;
            *)
                echo "$line" >> "$tempfile"
                ;;
        esac
    done < "$filename"

    if [ $changes -gt 0 ]; then
        # 将临时文件移动回原文件并设置原始权限
        mv "$tempfile" "$filename"
        chmod "$original_permissions" "$filename"
        echo -e "${GREEN}Completed processing $filename. Total changes: $changes${NC}"
        echo -e "${YELLOW}Original permissions ($original_permissions) preserved.${NC}"
        ((processed_files++))
        if [ "$has_airsafter_season" = true ]; then
            files_with_airsafter_season+=("$filename")
        fi
    else
        rm "$tempfile"
        echo -e "${RED}No changes needed in $filename${NC}"
        ((skipped_files++))
    fi
}

# 主程序开始

# 检查依赖
echo "Checking dependencies..."
check_dependencies

# 检查是否提供了文件名参数
if [ $# -eq 0 ]; then
    echo -e "${RED}Usage: $0 <filename1> [filename2] [filename3] ...${NC}"
    echo -e "${RED}   or: $0 *.nfo${NC}"
    exit 1
fi

echo -e "${GREEN}Starting XML file processing...${NC}"

# 遍历所有提供的参数（文件名）
for file in "$@"; do
    ((total_files++))
    process_file "$file"
    echo "----------------------------------------"
done

echo -e "${GREEN}Processing complete.${NC}"
echo "Total files: $total_files"
echo "Processed files: $processed_files"
echo "Skipped files: $skipped_files"

# 打印包含 <airsafter_season> 的文件列表
if [ ${#files_with_airsafter_season[@]} -gt 0 ]; then
    echo -e "\n${BLUE}Files containing <airsafter_season> tag:${NC}"
    printf '%s\n' "${files_with_airsafter_season[@]}"
fi