# ��ѹĿ¼
$extraPath = "F:\game\Cataclysme"
# ͼ����ļ���
$gtxPath = $extraPath + "\gfx"
# ��ѹ��ɺ�,���ļ���
$showFolder = $false
# �Ƿ�ʹ�ô���
$useProxy = $false
# �����ַ
$proxyUrl = "http://127.0.0.1:8087"
# ����ҳ��ҳ����
$url = "http://dev.narc.ro/cataclysm/jenkins-latest/Windows_x64/Tiles/"
# undead ����git����
$undead_git_url = "https://github.com/SomeDeadGuy/UndeadPeopleTileset.git"
# undead ��Ŀ��(�ļ�����)
$undead_project = "UndeadPeopleTileset"
# ����ͼ����ļ�����
$undead_folder_name = "MSX++UnDeadPeopleEdition"
$undead_folder_name2 = "MSX++UnDeadPeopleEditionLegacy"

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
#$filePath = $PSScriptRoot + "\" + $fileName
# ��ʱ�ý�ѹĿ¼
$filePath = $extraPath + "\" + $fileName
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
        Write-Progress -activity "������� '$($url.split('/') | Select-Object -Last 1)'"
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
    # undead��ŵ��ļ���, ��ϷĿ¼
    $undead_path = $extraPath + "\" + $undead_project
	$undead_folder = $undead_path + "\" + $undead_folder_name
    $undead_folder2 =$undead_path + "\" + $undead_folder_name2
    if (Test-Path $undead_path) {
        "undead �ļ����Ѵ���, ��ʼ��ȡ����"
        cd $undead_path
        git pull
	}else {
        "��ʼ����UnDead��Ŀ"
        cd $extraPath
        git clone $undead_git_url
        cd $undead_path
    }
    # ƴ��ͼ���·��
    $undead_gtx_path = $gtxPath + "\" + $undead_folder_name + "\"
    $undead_gtx_path2 = $gtxPath + "\" + $undead_folder_name2 + "\"
    # ����Ƿ��Ѵ����ļ���
    if ((Test-Path $undead_gtx_path)){
        "����ɰ�ͼ���"
        Remove-Item $undead_gtx_path -Force -Recurse
        
    }
    if (Test-Path $undead_gtx_path2) {
        "����ɰ�Legacyͼ���"
        Remove-Item $undead_gtx_path2 -Force -Recurse
    }
    Copy-Item $undead_folder -Destination $undead_gtx_path -Recurse
    Copy-Item $undead_folder2 -Destination $undead_gtx_path2 -Recurse
    # "$undead_folder ���Ƶ� $undead_gtx_path"
    "ͼ����Ѹ���"
}

Function Main() {
    DownloadFile $downloadUrl $filePath

    # $fileName = "cataclysmdda-0.C-8482.zip"
    "��ʼ��ѹ, ��ѹ�� --- " + $extraPath
    # ��ѹ
    Expand-Archive -Force -Path $filePath -DestinationPath $extraPath
    "��ѹ���, have fun~"

    # ��ʼundeadͼ�������
    "��ʼundeadͼ�������"
    DownloadUnDead

    #�򿪽�ѹ�ļ���
    if ($showFolder)
    {
	    explorer.exe $extraPath
    }
}

Main
