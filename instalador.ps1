# TODO: git path do endereços está errado
# TODO: problema de build no segurança

$pathDaInstalacao = "C:\ProjetosTFS";

Write-Output "### Buscando ferramentas"
$gitPath = (Get-ChildItem -Path "C:\" -Filter git.exe -Recurse -Depth 3 | Select-Object -First 1 | % { $_.FullName })
$appcmdPath = "C:\Windows\system32\inetsrv\appcmd.exe"
$msbuildPath = (Get-ChildItem -Path "C:\" -Filter msbuild.exe -Recurse -Depth 4 | Where-Object {$_.FullName -match "14.0\\Bin"} | Select-Object -First 1 | % { $_.FullName })

$mssqlPath = (Get-ChildItem -Path "C:\" -Recurse -Depth 3 | Where-Object {$_.FullName -match "Microsoft SQL Server\\MSSQL"} | Select-Object -First 1 | % { $_.FullName })
$sqlCmdPath = (Get-ChildItem -Path "C:\" -Filter sqlcmd.exe -Recurse -Depth 5 | Select-Object -First 1 | % { $_.FullName })

function habilitar_features_do_windows {
  Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerRole"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServer"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-CommonHttpFeatures"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpErrors"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ApplicationDevelopment"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-NetFxExtensibility"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-NetFxExtensibility45"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HealthAndDiagnostics"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpLogging"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-Security"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-RequestFiltering"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-Performance"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-WebServerManagementTools"
  Enable-WindowsOptionalFeature -Online -FeatureName "WAS-WindowsActivationService"
  Enable-WindowsOptionalFeature -Online -FeatureName "WAS-ProcessModel"
  Enable-WindowsOptionalFeature -Online -FeatureName "WAS-NetFxEnvironment"
  Enable-WindowsOptionalFeature -Online -FeatureName "WAS-ConfigurationAPI"
  Enable-WindowsOptionalFeature -Online -FeatureName "WCF-HTTP-Activation"
  Enable-WindowsOptionalFeature -Online -FeatureName "WCF-Services45"
  Enable-WindowsOptionalFeature -Online -FeatureName "WCF-HTTP-Activation45"
  Enable-WindowsOptionalFeature -Online -FeatureName "WCF-TCP-PortSharing45"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-StaticContent"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-DefaultDocument"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-DirectoryBrowsing"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ASPNET45"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ISAPIExtensions"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ISAPIFilter"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-HttpCompressionStatic"
  Enable-WindowsOptionalFeature -Online -FeatureName "IIS-ManagementConsole"
  Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4-AdvSrvs"
  Enable-WindowsOptionalFeature -Online -FeatureName "NetFx4Extended-ASPNET45"
  Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-NetFx-VCRedist-Package"
}

function clonar {
  param(
    [string]$nomeDoProjeto,
    [string]$nomeDaPasta)

  $url = "https://solucoesdigix.visualstudio.com/Projetos/_git/$($nomeDoProjeto)"

  Invoke-Expression "& '$($gitPath)' clone $($url) $($nomeDaPasta)"
}

function criar_aplicacao_no_iis {
  param(
    [string]$nome,
    [string]$url,
    [string]$pathDosBinarios)

  Invoke-Expression "& '$($appcmdPath)' delete app /app.name:'Default Web Site/$($nome)'"
  Invoke-Expression "& '$($appcmdPath)' add app /site.name:'Default Web Site' /app.name:'$($nome)' /path:'$($url)' /physicalPath:'$($pathDosBinarios)'"
}

function build {
  param(
    [string]$pathDaSolution)

  Invoke-Expression "& '$($msbuildPath)' $pathDaSolution -verbosity:quiet"
}

function restaurar_banco_de_dados {
  param(
    [string]$nomeDoBanco,
    [string]$pathDosBackups)

  Write-Output "### Restaurando $($nomeDoBanco)"

  $bakMaisRecente = Get-ChildItem -Path $pathDosBackups -Filter *.bak | Sort-Object LastAccessTime -Descending | Select-Object -First 1

  Copy-Item $bakMaisRecente.FullName -Destination $PWD -Force

  $pathDoBakCopiado = "$($PWD)\$($bakMaisRecente.Name)"
  
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$($nomeDoBanco)' DROP DATABASE [$($nomeDoBanco)]`""
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"CREATE DATABASE $($nomeDoBanco) ON (NAME = $($nomeDoBanco)_dat, FILENAME = '$($mssqlPath)\MSSQL\DATA\$($nomeDoBanco).mdf') LOG ON (NAME = $($nomeDoBanco)_log, FILENAME = '$($mssqlPath)\MSSQL\DATA\$($nomeDoBanco).ldf')`""
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"GO`""

  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"use [master]`""
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"ALTER DATABASE $($nomeDoBanco) SET SINGLE_USER WITH ROLLBACK IMMEDIATE`""

  # TODO: Entender (e arrumar aqui) porque o .bak do endereços é diferente e não tem mdf nem backup do log, fazendo com que o comando de restore seja diferente
  if ($nomeDoBanco -eq 'AGEHAB_enderecos') {
    Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"RESTORE DATABASE [$($nomeDoBanco)] FROM  DISK = N'$($pathDoBakCopiado)' WITH  FILE = 1,  NOUNLOAD,  REPLACE,  STATS = 5`""
  }

  else {
    Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"RESTORE DATABASE [$($nomeDoBanco)] FROM  DISK = N'$($pathDoBakCopiado)' WITH  FILE = 1,  MOVE N'$($nomeDoBanco)' TO N'$($mssqlPath)\MSSQL\DATA\$($nomeDoBanco).mdf',  MOVE N'$($nomeDoBanco)_log' TO N'$($mssqlPath)\MSSQL\DATA\$($nomeDoBanco)_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5`""
  }
  
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"ALTER DATABASE [$($nomeDoBanco)] SET MULTI_USER`""
  Invoke-Expression "& '$($sqlCmdPath)' -U sa -P sa -Q `"GO`""

  Remove-Item $pathDoBakCopiado
}

function clonar_projetos {
  Write-Output "### Clonando projetos"
  clonar "Domus-Administracao" "Administracao"
  clonar "Domus-Contemplados" "Contemplados"
  clonar "Domus-Seguranca" "Seguranca"
  clonar "Domus-Selecao" "Selecao"
  clonar "Domus-Tramitacao" "Tramitacao"
  clonar "Domus-Inscricao" "Inscricao"
  clonar "Domus-Enderecos" "Enderecos"
  clonar "Domus-UI" "UI"
}

function criar_aplicacoes_no_iis {
  Write-Host "### Criando aplicações no IIS"

  criar_aplicacao_no_iis "Administracao" "/Administracao" "$($PWD)\Administracao\src\Domus.Administracao.WebApp"
  criar_aplicacao_no_iis "Administracao/api" "/Administracao/api" "$($PWD)\Administracao\src\Domus.Administracao.WebApi"

  criar_aplicacao_no_iis "Contemplados" "/Contemplados" "$($PWD)\Contemplados\src\Domus.Contemplados.WebApp"
  criar_aplicacao_no_iis "Contemplados/api" "/Contemplados/api" "$($PWD)\Contemplados\src\Domus.Contemplados.WebApi"

  criar_aplicacao_no_iis "Seguranca" "/Seguranca" "$($PWD)\Seguranca\src\Domus.Seguranca.WebApp"
  criar_aplicacao_no_iis "Seguranca/api" "/Seguranca/api" "$($PWD)\Seguranca\src\Domus.Seguranca.WebApi"

  criar_aplicacao_no_iis "Selecao" "/Selecao" "$($PWD)\Selecao\src\Domus.Selecao.WebApp"
  criar_aplicacao_no_iis "Selecao/api" "/Selecao/api" "$($PWD)\Selecao\src\Domus.Selecao.WebApi"

  criar_aplicacao_no_iis "Tramitacao" "/Tramitacao" "$($PWD)\Tramitacao\src\Tramitacao.WebApp"
  criar_aplicacao_no_iis "Tramitacao/api" "/Tramitacao/api" "$($PWD)\Tramitacao\src\Tramitacao.WebApi"

  criar_aplicacao_no_iis "InscricaoWeb" "/InscricaoWeb" "$($PWD)\Inscricao\src\Domus.Inscricao.InscricaoWeb.WebApp"
  criar_aplicacao_no_iis "InscricaoWeb/api" "/InscricaoWeb/api" "$($PWD)\Inscricao\src\Domus.Inscricao.Inscricao.WebApi"
  criar_aplicacao_no_iis "InscricaoOnline" "/InscricaoOnline" "$($PWD)\Inscricao\src\Domus.Inscricao.InscricaoCompartilhada.WebApp"

  criar_aplicacao_no_iis "Enderecos" "/Enderecos" "$($PWD)\Enderecos\src\Domus.Enderecos.ServicosDistribuidos"
  criar_aplicacao_no_iis "Enderecos/api" "/Enderecos/api" "$($PWD)\Enderecos\src\Domus.Enderecos.WebApi"
}

function iniciar_iis {
  Write-Host "### Reiniciando IIS"
  Invoke-Expression "& '$($appcmdPath)' start site 'Default Web Site'"
}

function compilar_projetos {
  Write-Host "### Compilando projetos"

  $solutions = Get-ChildItem -path .\ -Filter *.sln -File -Name -Recurse -Depth 2

  foreach ($solution in $solutions) {
    Write-Host "### Compilando $($solution)"
    build $solution
  }
}

function restaurar_bancos_de_dados {
  restaurar_banco_de_dados "AGEHAB_ADMINISTRACAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Administracao\Producao"
  restaurar_banco_de_dados "AGEHAB_CONTEMPLADOS" "\\VESUVIO\DomusWeb_Bancos\Domus\Contemplados\Producao"
  restaurar_banco_de_dados "AGEHAB_DOMUS" "\\VESUVIO\DomusWeb_Bancos\Domus\Alternativo\Producao"
  restaurar_banco_de_dados "AGEHAB_DOMUS_SEGURANCA" "\\VESUVIO\DomusWeb_Bancos\Domus\Seguranca\Producao"
  restaurar_banco_de_dados "AGEHAB_INSCRICAO_WEB" "\\VESUVIO\DomusWeb_Bancos\Domus\Inscricao\Producao"
  restaurar_banco_de_dados "AGEHAB_SELECAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Selecao\Producao"
  restaurar_banco_de_dados "AGEHAB_TRAMITACAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Tramitacao\Producao"
  restaurar_banco_de_dados "AGEHAB_ENDERECOS" "\\VESUVIO\DomusWeb_Bancos\Domus\Enderecos\Producao"
}

function migrar_projetos {
  Write-Host "### Migrando projetos"

  $migrations = Get-ChildItem -path .\ -Filter migrations.proj -File -Name -Recurse -Depth 3

  foreach ($migration in $migrations) {
    Write-Host "### Migrando $($migration)"
    build $migration
  }
}

function validar_instalacao {
  if (!(Test-Path $pathDaInstalacao)) {
    Write-Error "O path informado ($($pathDaInstalacao)) para instalação não existe"
    exit
  }

  if (!(Test-Path $gitPath)) {
    Write-Error "cli do git não pôde ser encontrada, ele está instalado?"
    exit
  }

  if (!(Test-Path $appCmdPath)) {
    Write-Error "cli do IIS não pôde ser encontrado, ele está instalado?"
    exit
  }

  if (!(Test-Path $msbuildPath)) {
    Write-Error "cli da msbuild não pôde ser encontrada, ela está instalada?"
    exit
  }
}

function iniciar {
  $pathInformadoPeloUsuario = Read-Host -Prompt "Deseja instalar em qual diretório? (diretório padrão setado para $($pathDaInstalacao))"

  if ($pathInformadoPeloUsuario) {
    $pathDaInstalacao = $pathInformadoPeloUsuario
  }

  Write-Output "### Instalando features do windows"
  habilitar_features_do_windows

  Write-Output "### Validando instalação"
  validar_instalacao

  Write-Output "### Iniciando instalação"
  Set-Location $pathDaInstalacao
  mkdir Domus -ErrorAction SilentlyContinue
  Set-Location Domus

  clonar_projetos
  criar_aplicacoes_no_iis
  iniciar_iis
  compilar_projetos
  restaurar_bancos_de_dados
  migrar_projetos

  Write-Host "Instalação finalizada"
}

iniciar