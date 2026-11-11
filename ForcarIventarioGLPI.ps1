# ==========================================
# CONFIGURACAO (EDITE AQUI ANTES DE USAR)
# ==========================================
# URL de inventario do seu servidor GLPI
$GlpiServerUrl = "http://SEU_SERVIDOR_GLPI/front/inventory.php"
# Pagina aberta pelo atalho "Links Uteis" na Area de Trabalho
$LinksUrl      = "http://SEU_SERVIDOR_LINKS/"

# ==========================================
# PRE-REQUISITOS: PERMISSAO DE EXECUCAO
# ==========================================
Set-ExecutionPolicy Unrestricted -Scope Process -Force

Write-Host "[*] A aplicar regra de Firewall para permitir Ping (ICMPv4)..." -ForegroundColor Cyan

# Executa o comando e suprime a saída padrão de texto do netsh
$null = netsh advfirewall firewall add rule name="ICMP Allow incoming V4 echo request" protocol=icmpv4:8,any dir=in action=allow

# Verifica se o comando terminou com sucesso
if ($LASTEXITCODE -eq 0) {
    Write-Host "[+] Regra de Firewall (Ping/ICMPv4) adicionada com sucesso [OK]!" -ForegroundColor Green
} else {
    Write-Host "[-] Falha ao adicionar a regra de Firewall. O sistema pode bloquear o Ping." -ForegroundColor Red
}

# ==========================================
# 1. DESINSTALAR O FUSIONINVENTORY (CASO EXISTA)
# ==========================================
Write-Host "[*] Verificando se o FusionInventory Agent esta instalado..." -ForegroundColor:Cyan

$RegPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$FusionFound =$false

$RegPaths | ForEach-Object {
    if (-not $FusionFound) {
        $path =$_
        $keys = Get-Item -Path:$path -ErrorAction:SilentlyContinue
        if ($null -ne $keys) {$keys | ForEach-Object {
                if (-not $FusionFound) {
                    $key =$_
                    $displayName =$key.GetValue("DisplayName")
                    if ($displayName -like "*FusionInventory*") {
                        $FusionFound =$true
                        $uninstallString =$key.GetValue("UninstallString")
                        Write-Host "[+] FusionInventory encontrado. Iniciando desinstalacao..." -ForegroundColor:Yellow
                        
                        if ($uninstallString -like "*msiexec*") {
                            $uninstArgs =$uninstallString -replace "/I", "/X "
                            $uninstArgs = "$uninstArgs /quiet /norestart"
                            Start-Process -FilePath:"cmd.exe" -ArgumentList:"/c $uninstArgs" -Wait -NoNewWindow
                        } else {
                            Start-Process -FilePath:"msiexec.exe" -ArgumentList:"/x $($key.PSChildName) /quiet /norestart" -Wait -NoNewWindow
                        }
                        Write-Host "[+] FusionInventory desinstalado com sucesso!" -ForegroundColor:Green
                    }
                }
            }
        }
    }
}

if (-not $FusionFound) {
    Write-Host "[-] Nenhum FusionInventory Agent encontrado." -ForegroundColor:DarkGray
}

# ==========================================
# 2. VERIFICAR SE O GLPI AGENT JÁ ESTÁ INSTALADO
# ==========================================
Write-Host "[*] Verificando se o GLPI Agent ja esta instalado..." -ForegroundColor:Cyan

$GlpiFound =$false

$RegPaths | ForEach-Object {
    if (-not $GlpiFound) {
        $path =$_
        $keys = Get-Item -Path:$path -ErrorAction:SilentlyContinue
        if ($null -ne $keys) {$keys | ForEach-Object {
                if (-not $GlpiFound) {
                    $key =$_
                    $displayName =$key.GetValue("DisplayName")
                    if ($displayName -like "*GLPI-Agent*" -or $displayName -like "*GLPI Agent*") {
                        $GlpiFound =$true
                        Write-Host "[+] Encontrado no sistema: GLPI Agent" -ForegroundColor:Green
                    }
                }
            }
        }
    }
}

# Define o diretório atual de forma segura para usar na busca do MSI e do Ícone
if ($PSScriptRoot) {
    $CurrentDirectory =$PSScriptRoot
} else {
    $CurrentDirectory = (Get-Location).Path
}

# ==========================================
# DETECTAR VERSAO E ARQUITETURA DO WINDOWS (sempre executa)
# ==========================================
# Get-WmiObject e usado por compatibilidade com PowerShell 2.0/3.0 (Windows 7/8)
$OsInfo     = Get-WmiObject -Class:Win32_OperatingSystem
$OsCaption  = $OsInfo.Caption
$OsVersion  = $OsInfo.Version
$OsIs64Bits = [Environment]::Is64BitOperatingSystem

$OsArchLabel = if ($OsIs64Bits) { "64 bits" } else { "32 bits" }
Write-Host "[*] Sistema detectado: $OsCaption (versao $OsVersion) - $OsArchLabel" -ForegroundColor:Cyan

if ($GlpiFound) {
    Write-Host "[+] GLPI Agent ja esta instalado no sistema!" -ForegroundColor:Green
    Write-Host "[*] Atualizando o IP do servidor e forçando o envio do inventario..." -ForegroundColor:Yellow

    # URL do servidor definida no bloco de configuracao
    $NewServerUrl = $GlpiServerUrl
    $RegKeyPath = "HKLM:\SOFTWARE\GLPI-Agent"

    # Atualiza o IP no Registo do Windows
    if (Test-Path -Path:$RegKeyPath) {
        Set-ItemProperty -Path:$RegKeyPath -Name:"server" -Value:$NewServerUrl -Force
        Write-Host "[+] Endereco do servidor atualizado no Registro com sucesso!" -ForegroundColor:Green
        
        # Reinicia o servico do Windows na FORCA para evitar travamentos
        Write-Host "[*] Reiniciando o servico GLPI Agent para aplicar alteracao..." -ForegroundColor:Cyan
        Stop-Process -Name "glpi-agent" -Force -ErrorAction:SilentlyContinue
        Start-Sleep -Seconds 2
        Start-Service -Name:"glpi-agent" -ErrorAction:SilentlyContinue
    } else {
        Write-Host "[-] Nao foi possivel encontrar a chave de registro do GLPI Agent." -ForegroundColor:DarkGray
    }

    $GlpiClientPath = "C:\Program Files\GLPI-Agent\glpi-agent.bat"
    
    # Executa apenas o comando no terminal para forçar o envio
    if (Test-Path -Path:$GlpiClientPath) {
        & $GlpiClientPath --force
        Write-Host "[+] Inventario forçado e enviado com sucesso para o novo IP!" -ForegroundColor:Green
    } else {
        Write-Host "[-] Executavel do agente nao encontrado para forcar o inventario." -ForegroundColor:Red
    }

} else {
    # ==========================================
    # 3. INSTALAR O GLPI AGENT (A PARTIR DA PASTA LOCAL)
    # ==========================================
    Write-Host "[-] GLPI Agent nao encontrado. Iniciando processo de instalacao..." -ForegroundColor:Yellow

    # ------------------------------------------
    # 3.1 ESCOLHER O MSI CORRETO
    # ------------------------------------------
    # >>> AJUSTE AQUI os nomes dos instaladores <<<
    $MsiNameX86 = "GLPI-Agent-1.7-x86.msi"
    $MsiNameX64 = "GLPI-Agent-1.19-x64.msi"

    if ($OsIs64Bits) {
        $MsiName = $MsiNameX64
    } else {
        $MsiName = $MsiNameX86
    }
    Write-Host "[+] Instalador selecionado ($OsArchLabel): $MsiName" -ForegroundColor:Yellow

    $MsiServerUrl = $GlpiServerUrl
    
    # Busca o MSI na mesma pasta do script
    $MsiPath = Join-Path -Path:$CurrentDirectory -ChildPath:$MsiName

    if (Test-Path -Path:$MsiPath) {
        Write-Host "[+] Arquivo MSI encontrado em: $MsiPath" -ForegroundColor:Cyan
        
        $MsiArgs = @(
            "/i",
            "`"$MsiPath`"",
            "/quiet",
            "/norestart",
            "SERVER=$MsiServerUrl",
            "RUNNOW=1",
            "ADD_FIREWALL_EXCEPTION=1"
        )

        Write-Host "[*] Instalando o GLPI Agent... Aguarde." -ForegroundColor:Yellow
        $Process = Start-Process -FilePath:"msiexec.exe" -ArgumentList:$MsiArgs -Wait -PassThru -NoNewWindow
        
        if ($Process.ExitCode -eq 0) {
            Write-Host "[+] GLPI Agent instalado e inventario enviado com sucesso!" -ForegroundColor:Green
        } else {
            Write-Host "[-] A instalacao terminou com o codigo de erro: $($Process.ExitCode)" -ForegroundColor:Red
        }

    } else {
        Write-Host "[-] O arquivo MSI NAO foi encontrado na pasta local do script: $MsiPath" -ForegroundColor:Red
    }
}

# ==========================================
# 4. CRIAR O ATALHO DE LINKS ÚTEIS NA ÁREA DE TRABALHO PÚBLICA
# ==========================================
Write-Host "[*] Criando atalho de Links Uteis na Area de Trabalho..." -ForegroundColor:Cyan

$ShortcutName  = "Links Uteis.url"
$WebUrl        = $LinksUrl
$IconFileName  = "links-uteis_icone.ico"
$FolderName    = "atalho"

# Busca o ícone na mesma pasta onde o script está
$SourceIconPath = Join-Path -Path:$CurrentDirectory -ChildPath:$IconFileName

$PublicPictures = "$env:PUBLIC\Pictures"
$TargetFolder   = Join-Path -Path:$PublicPictures -ChildPath:$FolderName

if (-not (Test-Path -Path:$TargetFolder)) {
    New-Item -ItemType:Directory -Path:$TargetFolder -Force | Out-Null
}

$DestinationIconPath = Join-Path -Path:$TargetFolder -ChildPath:$IconFileName

if (Test-Path -Path:$SourceIconPath) {
    Copy-Item -Path:$SourceIconPath -Destination:$DestinationIconPath -Force
    Write-Host "[+] Icone copiado com sucesso" -ForegroundColor:Green
} else {
    Write-Host "[-] Aviso: O arquivo de icone nao foi encontrado na pasta do script." -ForegroundColor:Yellow
}

$DesktopPath  = [Environment]::GetFolderPath("CommonDesktopDirectory")
$ShortcutPath = Join-Path -Path:$DesktopPath -ChildPath:$ShortcutName

$UrlContent = @"
[InternetShortcut]
URL=$WebUrl
IconFile=$DestinationIconPath
IconIndex=0
"@

Set-Content -Path:$ShortcutPath -Value:$UrlContent -Encoding:ASCII
Write-Host "[+] Atalho criado com sucesso na Area de Trabalho Publica!" -ForegroundColor:Green

# ==========================================
# FIM DO SCRIPT
# ==========================================
Write-Host ""
Write-Host "Processo concluido com sucesso!" -ForegroundColor:Green
Write-Host "Pressione qualquer tecla para sair..." -ForegroundColor:Gray
$null =$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")