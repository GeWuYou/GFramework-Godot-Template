#!/usr/bin/env pwsh

<#
.SYNOPSIS
    重命名 GFramework-Godot-Template 项目
.DESCRIPTION
    将项目中的 "GFramework-Godot-Template" 和 "GFrameworkGodotTemplate" 替换为新项目名
.PARAMETER NewProjectName
    新项目名称
.PARAMETER WhatIf
    预览模式，不实际执行更改
.PARAMETER RemoveRenameTools
    重命名后删除重命名脚本和共享配置
.EXAMPLE
    .\rename_project.ps1 "MyAwesomeGame"
.EXAMPLE
    .\rename_project.ps1 "MyAwesomeGame" -WhatIf
.EXAMPLE
    .\rename_project.ps1 "MyAwesomeGame" -RemoveRenameTools
#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$NewProjectName,

    [switch]$WhatIf,

    [switch]$RemoveRenameTools
)

$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
    $scriptRoot = (Get-Location).Path
}

$configPath = Join-Path $scriptRoot "rename_project.config"

Push-Location -LiteralPath $scriptRoot
try {

function Read-RenameProjectConfig {
    param([string]$path)

    if (-not (Test-Path -LiteralPath $path)) {
        Write-Host "错误: 找不到配置文件: $path" -ForegroundColor Red
        exit 1
    }

    $config = @{}
    $configSection = ""
    foreach ($rawLine in Get-Content -LiteralPath $path -Encoding UTF8) {
        $line = $rawLine.Trim()
        if (-not [string]::IsNullOrWhiteSpace($line) -and -not $line.StartsWith("#")) {
            if ($line.StartsWith("[") -and $line.EndsWith("]")) {
                $configSection = $line.Substring(1, $line.Length - 2).Trim()
            } else {
                $separatorIndex = $line.IndexOf('=')
                if ($separatorIndex -ge 1) {
                    $key = $line.Substring(0, $separatorIndex).Trim()
                    $value = $line.Substring($separatorIndex + 1).Trim()
                    $config["$configSection.$key"] = $value
                }
            }
        }
    }

    $requiredKeys = @(
        'template.old_project_name',
        'template.old_namespace',
        'template.old_test_namespace',
        'scan.exclude_dirs',
        'scan.content_patterns',
        'cleanup.self_clean_files'
    )

    foreach ($requiredKey in $requiredKeys) {
        if (-not $config.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($config[$requiredKey])) {
            Write-Host "错误: 配置文件缺少必要项: $requiredKey" -ForegroundColor Red
            exit 1
        }
    }

    return $config
}

$config = Read-RenameProjectConfig $configPath

$OldProjectName = $config['template.old_project_name']
$OldNamespace = $config['template.old_namespace']
$OldTestNamespace = $config['template.old_test_namespace']

function ConvertTo-PascalCase {
    param([string]$name)
    
    $cleaned = $name -replace '[^a-zA-Z0-9]', ''
    if ($cleaned.Length -eq 0) {
        return ""
    }
    $pascal = $cleaned.Substring(0,1).ToUpper() + $cleaned.Substring(1)
    return $pascal
}

function Test-ProjectName {
    param([string]$name)
    
    if ($name -match '[^a-zA-Z0-9\-]') {
        Write-Host "错误: 项目名只能包含字母、数字和连字符" -ForegroundColor Red
        return $false
    }
    
    if ($name -match '^\d') {
        Write-Host "错误: 项目名不能以数字开头" -ForegroundColor Red
        return $false
    }
    
    if ($name.Length -lt 2 -or $name.Length -gt 50) {
        Write-Host "错误: 项目名长度必须在 2-50 字符之间" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Test-ExcludedPath {
    param(
        [string]$filePath,
        [string]$rootPath,
        [string[]]$excludeDirs
    )

    $relativePath = [System.IO.Path]::GetRelativePath($rootPath, $filePath)
    $pathParts = $relativePath -split '[\\/]+'

    foreach ($pathPart in $pathParts) {
        if ($excludeDirs -contains $pathPart) {
            return $true
        }
    }

    return $false
}

function Remove-RenameTools {
    param([string[]]$cleanupFiles)

    Write-Host "`n3. 清理重命名工具..." -ForegroundColor Cyan

    foreach ($cleanupFile in $cleanupFiles) {
        if ([string]::IsNullOrWhiteSpace($cleanupFile)) {
            continue
        }

        $cleanupPath = Join-Path $scriptRoot $cleanupFile
        if ($WhatIf) {
            Write-Host "  [删除] $cleanupFile" -ForegroundColor Cyan
        } elseif (Test-Path -LiteralPath $cleanupPath) {
            Remove-Item -LiteralPath $cleanupPath -Force
            Write-Host "  [删除] $cleanupFile" -ForegroundColor Green
        }
    }
}

function Update-FileContent {
    param(
        [string]$filePath,
        [hashtable]$replacements
    )
    
    $content = Get-Content $filePath -Raw -Encoding UTF8
    
    foreach ($key in $replacements.Keys) {
        $content = $content -replace [regex]::Escape($key), $replacements[$key]
    }
    
    if (-not $WhatIf) {
        Set-Content $filePath $content -NoNewline -Encoding UTF8
    }
}

function Rename-ProjectPath {
    param(
        [string]$sourcePath,
        [string]$oldName,
        [string]$newName
    )
    
    if (-not (Test-Path -LiteralPath $sourcePath)) { return }
    
    $newPath = $sourcePath.Replace($oldName, $newName)
    
    if ($WhatIf) {
        Write-Host "  [重命名] $sourcePath -> $newPath" -ForegroundColor Cyan
    } else {
        if (Test-Path -LiteralPath $newPath) {
            Write-Host "错误: 目标路径已存在: $newPath" -ForegroundColor Red
            exit 1
        }

        Rename-Item -LiteralPath $sourcePath -NewName (Split-Path -Leaf $newPath)
        Write-Host "  [重命名] $newPath" -ForegroundColor Green
    }
}

Write-Host "`n===== 项目重命名工具 =====" -ForegroundColor Cyan
Write-Host "旧项目名: $OldProjectName" -ForegroundColor Yellow
Write-Host "新项目名: $NewProjectName" -ForegroundColor Green

if (-not (Test-ProjectName $NewProjectName)) {
    exit 1
}

$NewNamespace = ConvertTo-PascalCase $NewProjectName
$NewTestNamespace = "$NewNamespace.Tests"
Write-Host "新命名空间: $NewNamespace" -ForegroundColor Green

$replacements = @{
    $OldProjectName = $NewProjectName
    $OldNamespace = $NewNamespace
    $OldTestNamespace = $NewTestNamespace
}

$excludeDirs = $config['scan.exclude_dirs'] -split ','

Write-Host "`n开始处理..." -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "[预览模式] 不会实际修改文件`n" -ForegroundColor Yellow
}

Write-Host "`n1. 更新文件内容..." -ForegroundColor Cyan

$filePatterns = $config['scan.content_patterns'] -split ','
$processedFiles = 0

$currentDir = Get-Location

foreach ($pattern in $filePatterns) {
    Get-ChildItem -Path . -Filter $pattern -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName $currentDir.Path $excludeDirs) } |
    ForEach-Object {
        $filePath = $_.FullName
        
        $hasChanges = $false
        $content = Get-Content $filePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        
        if ($content) {
            foreach ($key in $replacements.Keys) {
                if ($content -match [regex]::Escape($key)) {
                    $hasChanges = $true
                    break
                }
            }
        }
        
        if ($hasChanges) {
            $relPath = $filePath.Substring($currentDir.Path.Length + 1)
            
            if ($WhatIf) {
                Write-Host "  [更新] $relPath" -ForegroundColor Cyan
            } else {
                Update-FileContent $filePath $replacements
                Write-Host "  [更新] $relPath" -ForegroundColor Green
            }
            $processedFiles++
        }
    }
}

Write-Host "`n2. 重命名项目文件..." -ForegroundColor Cyan

Rename-ProjectPath "$OldProjectName.csproj" $OldProjectName $NewProjectName
Rename-ProjectPath "$OldProjectName.sln" $OldProjectName $NewProjectName

$oldTestProjectName = "$OldProjectName.Tests"
$newTestProjectName = "$NewProjectName.Tests"
$oldTestProjectDir = "tests/$oldTestProjectName"

Rename-ProjectPath "$oldTestProjectDir/$oldTestProjectName.csproj" "$oldTestProjectName.csproj" "$newTestProjectName.csproj"
Rename-ProjectPath $oldTestProjectDir $oldTestProjectName $newTestProjectName

$dotSettingsUserFile = "$OldProjectName.sln.DotSettings.user"
if (Test-Path $dotSettingsUserFile) {
    Rename-ProjectPath $dotSettingsUserFile $OldProjectName $NewProjectName
}

if ($RemoveRenameTools) {
    Remove-RenameTools ($config['cleanup.self_clean_files'] -split ',')
}

Write-Host "`n===== 完成 =====" -ForegroundColor Cyan
Write-Host "更新文件数: $processedFiles" -ForegroundColor Green

if (-not $WhatIf) {
    Write-Host "`n提示:" -ForegroundColor Yellow
    Write-Host "1. 在 Rider 中重新打开解决方案" -ForegroundColor White
    Write-Host "2. 运行清理命令: dotnet clean" -ForegroundColor White
    Write-Host "3. 重新构建项目: dotnet build" -ForegroundColor White
}
} finally {
    Pop-Location
}
