# ��ѹĿ¼
$extraPath = "E:\game\Cataclysme"
# ��ѹ��ɺ�,���ļ���
$showFolder = $false
# �Ƿ�ʹ�ô���
$useProxy = $true
# �����ַ
$proxyUrl = "http://127.0.0.1:8087"
#����ҳ��ҳ����
$url = "http://dev.narc.ro/cataclysm/jenkins-latest/Windows_x64/Tiles/"

#��ȡhtml�ļ�,תΪhtml����
$htmlDoc = (invoke-WebRequest $url).ParsedHTML
#�������� ��ǩ a���ı�
$contents = $htmlDoc.getElementsByTagName('a') | ForEach-Object {$_.innerText}
#$contents
$lastVersion = 0
#��ʼ�������б�ǩ�ı�
foreach ($n in $contents)
{
    #�����ļ���
    if ($n -match "cataclysmdda-(.*)-(\d+).zip")
    {
        #��ȡ�汾��
        $versionNum = $matches[0].Split("-")[$matches[0].Split("-").Count - 1].Split(".")[0]
        #��ȡ���°汾
        if ($versionNum -gt $lastVersion)
        {
            $lastVersion = $versionNum
            #���°汾���ļ���
            $fileName = $n
        }
    }
}
# �����ļ�����·��
$filePath = $PSScriptRoot + "\" + $fileName
# ƴ�����°汾��������
$downloadUrl = $url + $fileName
# �����ļ�
# ���
Function DownloadFileSimple($url, $targetFile)
{
    "��ʼ���� --- " + $targetFile
    # ���ؽ���
    # $ProgressPreference = 'silentlycontinue'
    # ����
    if ($useProxy) 
    {
        $proxy = [System.Net.HttpWebRequest]::GetSystemWebProxy().GetProxy($proxyUrl)
    }
    invoke-WebRequest -uri $url -OutFile $targetFile -Proxy $proxy
    #���powershell���ļ�����
    Unblock-File $fileName
    "������� --- " + $fileName
}
#.net�� ��ʾ����
Function DownloadFile($url, $targetFile) {
    $uri = New-Object "System.Uri" $url
    $request = [System.Net.HttpWebRequest]::Create($uri)
    # ����
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
        # ��ȡ �ܴ�С ��λKB
        $totalLength = [System.Math]::Floor($response.get_ContentLength() / 1025)
        "��ʼ���� --- " + $targetFile
        "�ܴ�С: " + [System.Math]::Floor($totalLength / 1024) + "M"
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
        Write-Progress -activity "������� '$($url.split('/') | Select-Object -Last 1)'"
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
"��ʼ��ѹ, ��ѹ�� --- " + $extraPath
#��ѹ
Expand-Archive -Force -Path $filePath -DestinationPath $extraPath
"��ѹ���, have fun~"
#�򿪽�ѹ�ļ���
if ($showFolder)
{
	explorer.exe $extraPath
}