# 解压目录
$extraPath = "E:\game\Cataclysme"
# 解压完成后,打开文件夹
$showFolder = $false
# 是否使用代理
$useProxy = $true
# 代理地址
$proxyUrl = "http://127.0.0.1:8087"
#发布页网页链接
$url = "http://dev.narc.ro/cataclysm/jenkins-latest/Windows_x64/Tiles/"

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
$filePath = $PSScriptRoot + "\" + $fileName
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
            if (($sw.Elapsed.TotalMilliseconds -ge 500) -or ($count -le 0)) {
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
        $targetStream.Flush()
        $targetStream.Close()
        $targetStream.Dispose()
        $responseStream.Dispose()
    }
}
DownloadFile $downloadUrl $filePath

#$fileName = "cataclysmdda-0.C-8482.zip"
"开始解压, 解压至 --- " + $extraPath
#解压
Expand-Archive -Force -Path $filePath -DestinationPath $extraPath
"解压完成, have fun~"
#打开解压文件夹
if ($showFolder)
{
	explorer.exe $extraPath
}