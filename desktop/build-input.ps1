$ErrorActionPreference='Stop'
$compiler=Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /optimize+ /target:exe /out:InputHost.exe /reference:System.Web.Extensions.dll /reference:System.Windows.Forms.dll InputHost.cs
if($LASTEXITCODE -ne 0){throw 'Input bridge build failed'}
