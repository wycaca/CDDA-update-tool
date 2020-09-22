# 解压目录
$extraPath = "F:\game\Cataclysme"
# 图像包文件夹
$gtxPath = $extraPath + "\gfx"
# 解压完成后,打开文件夹
$showFolder = $false
# 是否使用代理
$useProxy = $false
# 代理地址
$proxyUrl = "http://127.0.0.1:8087"
# 发布页网页链接
$url = "http://dev.narc.ro/cataclysm/jenkins-latest/Windows_x64/Tiles/"
# undead 发布git链接
$undead_git_url = "https://github.com/SomeDeadGuy/UndeadPeopleTileset.git"
# undead 项目名(文件夹名)
$undead_project = "UndeadPeopleTileset"
# 具体图像包文件夹名
$undead_folder_name = "MSX++UnDeadPeopleEdition"
$undead_folder_name2 = "MSX++UnDeadPeopleEditionLegacy"

#获取html文件,转为html对象
$htmlDoc = (invoke-WebRequest $url).ParsedHTML
#解析所有 标签 a的文本
$contents = $htmlDoc.getElementsByTagName('a') | ForEach-Object {$_.innerText}
#$contents
$lastVersion = 0
#开始遍历所有标签文本
foreach ($n in $contents)
{
    #过滤文件名
    if ($n -match "cataclysmdda-(.*)-(\d+).zip")
    {
        #提取版本号
        $versionNum = $matches[0].Split("-")[$matches[0].Split("-").Count - 1].Split(".")[0]
        #获取最新版本
        if ($versionNum -gt $lastVersion)
        {
            $lastVersion = $versionNum
            #最新版本的文件名
            $fileName = $n
        }
    }
}
# 保存文件完整路径
#$filePath = $PSScriptRoot + "\" + $fileName
# 暂时用解压目录
$filePath = $extraPath + "\" + $fileName
# 拼接最新版本下载链接
$downloadUrl = $url + $fileName
# 下载文件
# 最简单
Function DownloadFileSimple($url, $targetFile)
{
    "开始下载 --- " + $targetFile
    # 隐藏进度
    # $ProgressPreference = 'silentlycontinue'
    # 代理
    if ($useProxy) 
    {
        $proxy = [System.Net.HttpWebRequest]::GetSystemWebProxy().GetProxy($proxyUrl)
    }
    invoke-WebRequest -uri $url -OutFile $targetFile -Proxy $proxy
    #解除powershell的文件锁定
    Unblock-File $fileName
    "下载完成 --- " + $fileName
}
#.net类 显示进度
Function DownloadFile($url, $targetFile) {
    $uri = New-Object "System.Uri" $url
    $request = [System.Net.HttpWebRequest]::Create($uri)
    # 代理
    if ($useProxy)
    {
        $proxy = New-Object System.Net.WebProxy($proxyUrl)
        $proxy.useDefaultCredentials = $true
        $request.proxy = $proxy
    }
    $request.set_Timeout(15000) #15 second timeout
    try
    {
        $response = $request.GetResponse()
        # 获取 总大小 单位KB
        $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1025)
        "开始下载 --- " + $targetFile
        "总大小: " + [System.Math]::Floor($totalLength / 1024) + "M"
        $responseStream = $response.GetResponseStream()
        $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
        $buffer = new-object byte[] 10KB
        $count = $responseStream.Read($buffer, 0, $buffer.length)
        $downloadedBytes = $count
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $delta = 0
        while ($count -gt 0) {
            $targetStream.Write($buffer, 0, $count)
            $count = $responseStream.Read($buffer, 0, $buffer.length)
            $downloadedBytes = $downloadedBytes + $count
            $delta = $delta + $count
            if (($sw.Elapsed.TotalMilliseconds -ge 500) -or ($count -le 0))
            {
                #make it fast,avoid write-progress too often
                $percent = (([System.Math]::Floor($downloadedBytes / 1024)) / $totalLength) * 100
                $percentStr = '{0:n1}' -f $percent
                $speed = '{0:n2}' -f ($delta * 1000 / 1024 / $sw.Elapsed.TotalMilliseconds)
                Write-Progress -activity "Downloading file '$fileName'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K):$percentStr% $speed KB/s" -PercentComplete $percent
                $sw.Reset(); $sw.Start(); $delta = 0
            }
        }
        Write-Progress -activity "下载完成 '$($url.split('/') | Select-Object -Last 1)'"
    }
    Finally
    {
        if ($null -ne $targetStream)
        {
            $targetStream.Flush()
            $targetStream.Close()
            $targetStream.Dispose()
            $responseStream.Dispose()
        }
    }
}

Function DownloadUnDead() {
    # undead存放的文件夹, 游戏目录
    $undead_path = $extraPath + "\" + $undead_project
	$undead_folder = $undead_path + "\" + $undead_folder_name
    $undead_folder2 =$undead_path + "\" + $undead_folder_name2
    if (Test-Path $undead_path) {
        "undead 文件夹已存在, 开始拉取更新"
        cd $undead_path
        git pull
	}else {
        "开始下载UnDead项目"
        cd $extraPath
        git clone $undead_git_url
        cd $undead_path
    }
    # 拼接图像包路径
    $undead_gtx_path = $gtxPath + "\" + $undead_folder_name + "\"
    $undead_gtx_path2 = $gtxPath + "\" + $undead_folder_name2 + "\"
    # 检测是否已存在文件夹
    if ((Test-Path $undead_gtx_path)){
        "清理旧版图像包"
        Remove-Item $undead_gtx_path -Force -Recurse
        
    }
    if (Test-Path $undead_gtx_path2) {
        "清理旧版Legacy图像包"
        Remove-Item $undead_gtx_path2 -Force -Recurse
    }
    Copy-Item $undead_folder -Destination $undead_gtx_path -Recurse
    Copy-Item $undead_folder2 -Destination $undead_gtx_path2 -Recurse
    # "$undead_folder 复制到 $undead_gtx_path"
    "图像包已复制"
}

Function Main() {
    DownloadFile $downloadUrl $filePath

    # $fileName = "cataclysmdda-0.C-8482.zip"
    "开始解压, 解压至 --- " + $extraPath
    # 解压
    Expand-Archive -Force -Path $filePath -DestinationPath $extraPath
    "解压完成, have fun~"

    # 开始undead图像包处理
    "开始undead图像包处理"
    DownloadUnDead

    #打开解压文件夹
    if ($showFolder)
    {
	    explorer.exe $extraPath
    }
}

Main
