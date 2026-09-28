function Invoke-ScheduledTask {

    #Requires -Version 3.0

    [cmdletbinding()]
    Param(
    [Parameter(Mandatory = $true)][ScriptBlock]$ScriptBlock,
    [Parameter(Mandatory = $false)][Object[]]$ArgumentList,
    [Parameter(Mandatory = $false)][PSCredential][System.Management.Automation.CredentialAttribute()]$AsUser,
    [Parameter(Mandatory = $false)][Switch]$AsSystem,
    [Parameter(Mandatory = $false)][String]$AsInteractive,
    [Parameter(Mandatory = $false)][String]$AsGMSA,
    [Parameter(Mandatory = $false)][Switch]$RunElevated

    )

    Process {

        $JobName = [guid]::NewGuid().Guid
        Write-Verbose "$(Get-Date): ScheduledJob: Name: ${JobName}"

        $UseScheduledTask = If (Get-Command 'Register-ScheduledTask' -ErrorAction SilentlyContinue) { $True } Else { $False }

        $TempDir = $Null
        $ScheduledTask = $Null
        $ScheduleTaskFolder = $Null

        Try {

            If (-not ($AsSystem -or $AsInteractive -or $AsUser -or $AsGMSA)) {

                # No identity change requested, run in the background as the current user.
                # Start-Job natively resolves $Using: variables from this scope, so the
                # ScriptBlock/ArgumentList can be passed through untouched.

                Write-Verbose "$(Get-Date): Job: Start"
                Start-Job -Name $JobName -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList | Wait-Job | Receive-Job -Wait -AutoRemoveJob

                Return

            }

            # An identity change was requested. Since this has to run as a separate process
            # (launched by the Task Scheduler), $Using: variables can't be resolved through
            # scope the way Start-Job does it. Resolve them here and bake their values into
            # a standalone script, run by the same PowerShell engine (Desktop or Core) that
            # is hosting this function, and hand back the results via Clixml files.

            # Little bit of inception to get $Using variables to work.
            # Collect $Using:variables, Rename and set new variables inside the script.

            # Inspired by Boe Prox, and his https://github.com/proxb/PoshRSJob module
            #      and by Warren Framem and his https://github.com/RamblingCookieMonster/Invoke-Parallel module

            $UsingList = @()
            $UsingVariables = $ScriptBlock.ast.FindAll({$args[0] -is [System.Management.Automation.Language.UsingExpressionAst]},$True)
            If ($UsingVariables) {

                $ScriptText = $ScriptBlock.Ast.Extent.Text
                $ScriptOffSet = $ScriptBlock.Ast.Extent.StartOffset
                ForEach ($SubExpression in ($UsingVariables.SubExpression | Sort-Object { $_.Extent.StartOffset } -Descending)) {

                    $Name = '__using_{0}' -f (([Guid]::NewGuid().guid) -Replace '-')
                    $Expression = $SubExpression.Extent.Text.Replace('$Using:','$').Replace('${Using:','${');
                    $Value = Invoke-Expression $Expression
                    $UsingList += [PSCustomObject]@{ Name = $Name; Value = $Value }
                    $ScriptText = $ScriptText.Substring(0, ($SubExpression.Extent.StartOffSet - $ScriptOffSet)) + "`$$Name" + $ScriptText.Substring(($SubExpression.Extent.EndOffset - $ScriptOffSet))

                }
                $ScriptBlock = [ScriptBlock]::Create($ScriptText.TrimStart("{").TrimEnd("}"))
            }

            $TempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $JobName
            New-Item -Path $TempDir -ItemType Directory -Force | Out-Null

            $ScriptPath        = Join-Path -Path $TempDir -ChildPath 'script.ps1'
            $ArgumentListPath  = Join-Path -Path $TempDir -ChildPath 'arguments.xml'
            $UsingPath         = Join-Path -Path $TempDir -ChildPath 'using.xml'
            $OutputPath        = Join-Path -Path $TempDir -ChildPath 'output.xml'
            $ErrorPath         = Join-Path -Path $TempDir -ChildPath 'error.xml'
            $BootstrapPath     = Join-Path -Path $TempDir -ChildPath 'bootstrap.ps1'

            Set-Content -Path $ScriptPath -Value $ScriptBlock.ToString() -Encoding UTF8
            If ($ArgumentList) { $ArgumentList | Export-Clixml -Path $ArgumentListPath -Depth 5 }
            If ($UsingList)    { $UsingList    | Export-Clixml -Path $UsingPath -Depth 5 }

            # Generic bootstrap script: takes no user content directly, only file paths,
            # so it works identically under Windows PowerShell and PowerShell 7.
            $BootstrapContent = @'
param(
    [string]$ScriptPath,
    [string]$ArgumentListPath,
    [string]$UsingPath,
    [string]$OutputPath,
    [string]$ErrorPath
)

$ErrorActionPreference = 'Stop'

Try {

    $ScriptText  = Get-Content -Path $ScriptPath -Raw
    $ScriptBlock = [ScriptBlock]::Create($ScriptText)

    $ArgumentList = @()
    If (Test-Path -Path $ArgumentListPath) { $ArgumentList = @(Import-Clixml -Path $ArgumentListPath) }

    If (Test-Path -Path $UsingPath) {
        ForEach ($UsingVariable in (Import-Clixml -Path $UsingPath)) {
            Set-Variable -Name $UsingVariable.Name -Value $UsingVariable.Value
        }
    }

    $Output = & $ScriptBlock @ArgumentList
    $Output | Export-Clixml -Path $OutputPath -Depth 5

} Catch {

    $_ | Export-Clixml -Path $ErrorPath -Depth 5
    Exit 1

}
'@
            Set-Content -Path $BootstrapPath -Value $BootstrapContent -Encoding UTF8

            # Run the bootstrap script with the same PowerShell engine (powershell.exe on
            # Desktop, pwsh.exe on Core) that is hosting this function, so the executed
            # scriptblock behaves the same way it would locally.
            $ExecutablePath = (Get-Process -Id $PID).Path
            $ExecutableArguments = '-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -File "{0}" -ScriptPath "{1}" -ArgumentListPath "{2}" -UsingPath "{3}" -OutputPath "{4}" -ErrorPath "{5}"' -f `
                $BootstrapPath, $ScriptPath, $ArgumentListPath, $UsingPath, $OutputPath, $ErrorPath

            If ($UseScheduledTask) {

                # For Windows 8 / Server 2012 and Newer

                Write-Verbose "$(Get-Date): ScheduledTask: Register"
                $TaskParameters = @{ TaskName = $JobName }
                $TaskParameters['Action'] = New-ScheduledTaskAction -Execute $ExecutablePath -Argument $ExecutableArguments
                $TaskParameters['Settings'] = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
                If ($AsSystem) {
                    $TaskParameters['Principal'] = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                } ElseIf ($AsGMSA) {
                    $TaskParameters['Principal'] = New-ScheduledTaskPrincipal -UserID $AsGMSA -LogonType Password -RunLevel Highest
                } ElseIf ($AsInteractive) {
                    $TaskParameters['Principal'] = New-ScheduledTaskPrincipal -UserID $AsInteractive -LogonType Interactive -RunLevel Highest
                } ElseIf ($AsUser) {
                    $TaskParameters['User'] = $AsUser.GetNetworkCredential().UserName
                    $TaskParameters['Password'] = $AsUser.GetNetworkCredential().Password
                }
                If ($RunElevated.IsPresent) {
                    $TaskParameters['RunLevel'] = 'Highest'
                }

                $ScheduledTask = Register-ScheduledTask @TaskParameters -ErrorAction Stop

                Write-Verbose "$(Get-Date): ScheduledTask: Start"
                $CimJob = $ScheduledTask | Start-ScheduledTask -AsJob -ErrorAction Stop
                $CimJob | Wait-Job | Remove-Job -Force -Confirm:$False

                Write-Verbose "$(Get-Date): ScheduledTask: Wait"
                While (($ScheduledTaskInfo = $ScheduledTask | Get-ScheduledTaskInfo).LastTaskResult -eq 267009) { Start-Sleep -Milliseconds 200 }

            } Else {

                # For Windows 7 / Server 2008 R2

                Write-Verbose "$(Get-Date): ScheduleService: Register"
                $ScheduleService = New-Object -ComObject("Schedule.Service")
                $ScheduleService.Connect()
                $ScheduleTaskFolder = $ScheduleService.GetFolder("\")
                $TaskDefinition = $ScheduleService.NewTask(0)
                $TaskDefinition.Principal.RunLevel = $RunElevated.IsPresent
                $TaskAction = $TaskDefinition.Actions.Create(0)
                $TaskAction.Path = $ExecutablePath
                $TaskAction.Arguments = $ExecutableArguments

                If ($AsUser) {
                    $Username = $AsUser.GetNetworkCredential().UserName
                    $Password = $AsUser.GetNetworkCredential().Password
                    $LogonType = 1
                } ElseIf ($AsInteractive) {
                    $Username = $AsInteractive
                    $Password = $null
                    $LogonType = 3
                    $TaskDefinition.Principal.RunLevel = 1
                } ElseIf ($AsSystem) {
                    $Username = "System"
                    $Password = $null
                    $LogonType = 5
                } ElseIf ($AsGMSA) {
                    # Needs to be tested
                    $Username = $AsGMSA
                    $Password = $null
                    $LogonType = 5
                }


                $RegisteredTask = $ScheduleTaskFolder.RegisterTaskDefinition($JobName,$TaskDefinition,6,$Username,$Password,$LogonType)

                Write-Verbose "$(Get-Date): ScheduleService: Start"
                $ScheduledTask = $RegisteredTask.Run($null)

                Write-Verbose "$(Get-Date): ScheduleService: Wait: Start"
                Do { $ScheduledTaskInfo = $ScheduleTaskFolder.GetTasks(1) | Where-Object Name -eq $ScheduledTask.Name; Start-Sleep -Milliseconds 100 }
                While ($ScheduledTaskInfo.State -eq 3 -and $ScheduledTaskInfo.LastTaskResult -eq 267045)

                Write-Verbose "$(Get-Date): ScheduleService: Wait: End"
                Do { $ScheduledTaskInfo = $ScheduleTaskFolder.GetTasks(1) | Where-Object Name -eq $ScheduledTask.Name; Start-Sleep -Milliseconds 100 }
                While ($ScheduledTaskInfo.State -eq 4)

            }

            If ($ScheduledTaskInfo.LastRunTime.Year -ne (Get-Date).Year) {
                Write-Error 'Task was unable to be executed.'
                Return
            }

            Write-Verbose "$(Get-Date): ScheduledTask: Receive"
            If (Test-Path -Path $ErrorPath) {
                $TaskError = Import-Clixml -Path $ErrorPath
                Write-Error -Message $TaskError.ToString()
            } ElseIf (Test-Path -Path $OutputPath) {
                Import-Clixml -Path $OutputPath
            }

        } Catch {

            Write-Verbose "$(Get-Date): TryCatch: Error"
            Write-Error $_

        } Finally {

            Write-Verbose "$(Get-Date): ScheduledTask: Unregister"
            If ($ScheduledTask) {
                If ($UseScheduledTask) {
                    $ScheduledTask | Get-ScheduledTask -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$False | Out-Null
                } Else {
                    $ScheduleTaskFolder.DeleteTask($ScheduledTask.Name, 0) | Out-Null
                }
            }

            Write-Verbose "$(Get-Date): TempDir: Remove"
            If ($TempDir) { Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue }

        }

    }

}
