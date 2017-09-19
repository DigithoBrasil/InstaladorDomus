Write-Output "### Buscando ferramentas"
$gitPath = (Get-ChildItem -Path "C:\" -Filter git.exe -Recurse -Depth 3 | Select-Object -First 1 | % { $_.FullName }).Replace("Program Files\", "PROGRA~1\")
$appcmdPath = "C:\Windows\system32\inetsrv\appcmd.exe"
$msbuildPath = (Get-ChildItem -Path "C:\" -Filter msbuild.exe -Recurse -Depth 4 | Where-Object {$_.FullName -match "14.0\\Bin"} | Select-Object -First 1 | % { $_.FullName }).Replace("Program Files\", "PROGRA~1\").Replace("Program Files (x86)\", "PROGRA~2\")

function clonar {
  param(
    [string]$nomeDoProjeto,
    [string]$nomeDaPasta)

  $url = "https://solucoesdigix.visualstudio.com/Projetos/_git/$($nomeDoProjeto)"

  Invoke-Expression "$($gitPath) clone $($url) $($nomeDaPasta)"
}

function criar_aplicacao_no_iis {
  param(
    [string]$nome,
    [string]$url,
    [string]$pathDosBinarios)

  Invoke-Expression "$($appcmdPath) delete app /app.name:'Default Web Site/$($nome)'"
  Invoke-Expression "$($appcmdPath) add app /site.name:'Default Web Site' /app.name:'$($nome)' /path:'$($url)' /physicalPath:'$($pathDosBinarios)'"
}

function build {
  param(
    [string]$pathDaSolution)

  Invoke-Expression "$($msbuildPath) $pathDaSolution -verbosity:quiet"
}

function restaurar_banco_de_dados {
  param(
    [string]$nomeDoBanco,
    [string]$pathDosBackups)

  Write-Output "### Restaurando $($nomeDoBanco)"

  $bakMaisRecente = Get-ChildItem -Path $pathDosBackups -Filter *.bak | Sort-Object LastAccessTime -Descending | Select-Object -First 1

  Copy-Item $bakMaisRecente.FullName -Destination $PWD -Force

  $pathDoBakCopiado = "$($PWD)\$($bakMaisRecente.Name)"
  
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'$($nomeDoBanco)' DROP DATABASE [$($nomeDoBanco)]`""
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"CREATE DATABASE $($nomeDoBanco) ON (NAME = $($nomeDoBanco)_dat, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\$($nomeDoBanco).mdf') LOG ON (NAME = $($nomeDoBanco)_log, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\$($nomeDoBanco).ldf')`""
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"GO`""

  Invoke-Expression "sqlcmd -U sa -P sa -Q `"use [master]`""
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"ALTER DATABASE $($nomeDoBanco) SET SINGLE_USER WITH ROLLBACK IMMEDIATE`""

  # TODO: Entender (e arrumar aqui) porque o .bak do endereços é diferente e não tem mdf nem backup do log, fazendo com que o comando de restore seja diferente
  if ($nomeDoBanco -eq 'AGEHAB_enderecos') {
    Invoke-Expression "sqlcmd -U sa -P sa -Q `"RESTORE DATABASE [$($nomeDoBanco)] FROM  DISK = N'$($pathDoBakCopiado)' WITH  FILE = 3,  NOUNLOAD,  REPLACE,  STATS = 5`""
  }

  else {
    Invoke-Expression "sqlcmd -U sa -P sa -Q `"RESTORE DATABASE [$($nomeDoBanco)] FROM  DISK = N'$($pathDoBakCopiado)' WITH  FILE = 1,  MOVE N'$($nomeDoBanco)' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\$($nomeDoBanco).mdf',  MOVE N'$($nomeDoBanco)_log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\$($nomeDoBanco)_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5`""
  }
  
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"ALTER DATABASE [$($nomeDoBanco)] SET MULTI_USER`""
  Invoke-Expression "sqlcmd -U sa -P sa -Q `"GO`""

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
  clonar "Enderecos" "Enderecos"
  clonar "Domus-UI" "UI"
}

function criar_aplicacoes_no_iis {
  Write-Host "### Criando aplicações no IIS"

  criar_aplicacao_no_iis "Administracao" "/Administracao" "Domus\Administracao\src\Domus.Administracao.WebApp"

  criar_aplicacao_no_iis "Contemplados" "/Contemplados" "Domus\Contemplados\src\Domus.Contemplados.WebApp"

  criar_aplicacao_no_iis "Seguranca" "/Seguranca" "Domus\Seguranca\src\Domus.Seguranca.WebApp"

  criar_aplicacao_no_iis "Selecao" "/Selecao" "Domus\Selecao\src\Domus.Selecao.WebApp"
  criar_aplicacao_no_iis "Selecao/api" "/Selecao/api" "Domus\Selecao\src\Domus.Selecao.WebApi"

  criar_aplicacao_no_iis "Tramitacao" "/Tramitacao" "Domus\Tramitacao\src\Tramitacao.WebApp"

  criar_aplicacao_no_iis "InscricaoWeb" "/InscricaoWeb" "Domus\Inscricao\src\Domus.Inscricao.InscricaoWeb.WebApp"
  criar_aplicacao_no_iis "InscricaoOnline" "/InscricaoOnline" "Domus\Inscricao\src\Domus.Inscricao.InscricaoCompartilhada.WebApp"

  criar_aplicacao_no_iis "Enderecos" "/Enderecos" "Domus\Enderecos\src\Domus.Enderecos.ServicosDistribuidos"
  criar_aplicacao_no_iis "Enderecos/api" "/Enderecos/api" "Domus\Enderecos\src\Domus.Enderecos.WebApi"
}

function iniciar_iis {
  Write-Host "### Reiniciando IIS"
  Invoke-Expression "$($appcmdPath) start site 'Default Web Site'"
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
  if (!(Test-Path $gitPath)) {
    Write-Error "cli do git não pôde ser encontrada, ele está instalado?"
  }

  if (!(Test-Path $appCmdPath)) {
    Write-Error "cli do IIS não pôde ser encontrado, ele está instalado?"
  }

  if (!(Test-Path $msbuildPath)) {
    Write-Error "cli da msbuild não pôde ser encontrada, ela está instalada?"
  }
}

function iniciar {
  Write-Output "### Validando instalação"
  validar_instalacao

  Write-Output "### Iniciando instalação"
  Set-Location D:\ProjetosTFS\
  mkdir Domus -ErrorAction SilentlyContinue
  Set-Location Domus

  # clonar_projetos
  criar_aplicacoes_no_iis
  iniciar_iis
  compilar_projetos
  restaurar_bancos_de_dados
  migrar_projetos
}

iniciar