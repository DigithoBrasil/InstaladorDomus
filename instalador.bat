@echo off
mkdir ProjetosTFS\Domus
cd ProjetosTFS\Domus

call:clonar "Domus-Administracao" "Administracao"
call:criarapp "Administracao" "/Administracao" "Domus\Administracao\src\Domus.Administracao.WebApp"

call:clonar "Domus-Alternativo" "Alternativo"
call:criarapp "Alternativo" "/DomusWeb" "Domus\Alternativo\src\Domus.WebApp"

call:clonar "Domus-Contemplados" "Contemplados"
call:criarapp "Contemplados" "/Contemplados" "Domus\Contemplados\src\Domus.Contemplados.WebApp"

call:clonar "Domus-Seguranca" "Seguranca"
call:criarapp "Seguranca" "/Seguranca" "Domus\Seguranca\src\Domus.Seguranca.WebApp"

call:clonar "Domus-Selecao" "Selecao"
call:criarapp "Selecao" "/Selecao" "Domus\Selecao\src\Domus.Selecao.WebApp"
call:criarapp "Selecao/api" "/Selecao/api" "Domus\Selecao\src\Domus.Selecao.WebApi"

call:clonar "Domus-Tramitacao" "Tramitacao"
call:criarapp "Tramitacao" "/Tramitacao" "Domus\Tramitacao\src\Tramitacao.WebApp"

call:clonar "Domus-Inscricao" "Inscricao"
call:criarapp "InscricaoWeb" "/InscricaoWeb" "Domus\Inscricao\src\Domus.Inscricao.InscricaoWeb.WebApp"
call:criarapp "InscricaoOnline" "/InscricaoOnline" "Domus\Inscricao\src\Domus.Inscricao.InscricaoCompartilhada.WebApp"

call:clonar "Enderecos" "Enderecos"
call:criarapp "Enderecos" "/Enderecos" "Domus\Enderecos\src\Domus.Enderecos.ServicosDistribuidos"
call:criarapp "Enderecos/api" "/Enderecos/api" "Domus\Enderecos\src\Domus.Enderecos.WebApi"

call:iniciariis
call:compilartodos
call:migrartodos

call:restaurardb "AGEHAB_ADMINISTRACAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Administracao\Producao"
call:restaurardb "AGEHAB_CONTEMPLADOS" "\\VESUVIO\DomusWeb_Bancos\Domus\Contemplados\Producao"
call:restaurardb "AGEHAB_DOMUS" "\\VESUVIO\DomusWeb_Bancos\Domus\Alternativo\Producao"
call:restaurardb "AGEHAB_DOMUS_SEGURANCA" "\\VESUVIO\DomusWeb_Bancos\Domus\Seguranca\Producao"
call:restaurardb "AGEHAB_INSCRICAO_WEB" "\\VESUVIO\DomusWeb_Bancos\Domus\Inscricao\Producao"
call:restaurardb "AGEHAB_SELECAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Selecao\Producao"
call:restaurardb "AGEHAB_TRAMITACAO" "\\VESUVIO\DomusWeb_Bancos\Domus\Tramitacao\Producao"
call:restaurardb "AGEHAB_ENDERECOS" "\\VESUVIO\DomusWeb_Bancos\Domus\Enderecos\Producao"

echo.&pause&goto:eof

:clonar
git clone http://tfs01:8080/tfs/DigithoBrasil/Solu%%C3%%A7%%C3%%B5es%%20em%%20Software/_git/%~1
rename %~1 %~2
goto:eof

:criarapp
appcmd delete app /app.name:"Default Web Site%~2"
appcmd add app /site.name:"Default Web Site" /app.name:"%~1" /path:"%~2" /physicalPath:"D:\ProjetosTFS\%~3"
goto:eof

:iniciariis
appcmd start site "Default Web Site"
goto:eof

:compilartodos
for /f "tokens=*" %%a in ('dir /b /s *.sln') do call:build %%a
goto:eof

:migrartodos
for /f "tokens=*" %%a in ('dir /b /s migrations.proj') do call:build %%a
goto:eof

:build
echo ### Compilando %~1
msbuild %~1 -verbosity:quiet
goto:eof

:recriardb
echo ### Restaurando %~1
sqlcmd -U sa -P sa -Q "EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'%~1' DROP DATABASE [%~1]"
sqlcmd -U sa -P sa -Q "CREATE DATABASE %~1 ON (NAME = %~1_dat, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\%~1.mdf') LOG ON (NAME = %~1_log, FILENAME = 'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\%~1.ldf')"
goto:eof

:restaurardb
call:recriardb "%~1"

pushd %~2
for /f "tokens=*" %%a in ('dir /b /od *.bak') do set newest=%%a
sqlcmd -U sa -P sa -Q "RESTORE DATABASE [%~1] FROM  DISK = N'%~2\%newest%' WITH  FILE = 1,  MOVE N'%~1' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\%~1.mdf',  MOVE N'%~1_log' TO N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\%~1_log.ldf',  NOUNLOAD,  REPLACE,  STATS = 5"
popd
goto:eof