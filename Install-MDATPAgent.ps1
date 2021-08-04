function Install-MDATPAgent {
    <#
    .SPNOPSYS
        Install the MDATP MMA Agent

    .DESCRIPTION
        This will download and configure the MMA (Microsoft Monitoring Agent) to the local computer and configure it

    .PARAMETER FilePathToExtract
        File path to extract local MMA package

    .PARAMETER WorkspaceID
        Azure MDATP workspace id

    .PARAMETER WorkspaceKey
        Azure MDATP workspace key

    .PARAMETER LoggingPath
        Default log file path

    .PARAMETER LoggingFile
        Default log file name

    .EXAMPLE
        PS C:\> Install-MDATPAgent -WorkspaceID YourAzureTenantYourID -WorkspaceKey YourAzureTenantYourKey

        Installs the MDATP monitoring agent to a machine

    .NOTES
        https://docs.microsoft.com/en-us/azure/azure-monitor/agents/agent-windows#install-agent-using-command-line

        MMA-specific options	
        NOAPM=1	Optional parameter. Installs the agent without .NET Application Performance Monitoring.
        ADD_OPINSIGHTS_WORKSPACE	1 = Configure the agent to report to a workspace
        OPINSIGHTS_WORKSPACE_ID	Workspace ID (guid) for the workspace to add
        OPINSIGHTS_WORKSPACE_KEY	Workspace key used to initially authenticate with the workspace
        OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE	Specify the cloud environment where the workspace is located
        0 = Azure commercial cloud (default)
        1 = Azure Government
        OPINSIGHTS_PROXY_URL	URI for the proxy to use
        OPINSIGHTS_PROXY_USERNAME	Username to access an authenticated proxy
        OPINSIGHTS_PROXY_PASSWORD	Password to access an authenticated proxy
#>

    [cmdletbinding()]
    param(
        [string]
        $FilePathToExtract = 'c:\MMAAgentFiles',

        [string]
        $WorkspaceID = "YourWorkspaceID",

        [string]
        $WorkspaceKey = "YourWorkspaceKey",

        [string]
        $LoggingPath = "C:\Logging\",
        
        [string]
        $LoggingFile = "MDATPAgentLog.txt"
    )

    begin {
        Write-Host -ForegroundColor Green "Starting MMA configuration process"
    }

    process {

        try {
            Start-Transcript -Path (Join-Path -Path $LoggingPath -ChildPath $LoggingFile) -Append
            Write-Host -ForegroundColor Cyan "Output path: $($env:TEMP)`nMMA Agent extraction path: $($FilePathToExtract)"
            $outpath = "$env:TEMP\MMASetup-AMD64.exe"
            $url = 'https://download.microsoft.com/download/3/c/d/3cd6f5b3-3fbe-43c0-88e0-8256d02db5b7/MMASetup-AMD64.exe'
            Write-Host -ForegroundColor Green "Checking to see if MMA Agent has already been downloaded to $($env:ComputerName)"

            if (-NOT (Test-Path -Path $env:TEMP\MMASetup-AMD64.exe)) {
                Write-Host -ForegroundColor Green "Not found! Downloading MMA Agent to $($env:ComputerName)"
                Invoke-WebRequest -Uri $url -OutFile $outpath
            }
            else {
                Write-Host -ForegroundColor Green "MMA Agent has been previously downloaded!"
            }
        }
        catch {
            "Error: $_"
        }

        try {
            Write-Host -ForegroundColor Yellow "Extracting MMA package contents to $($FilePathToExtract)."
            Start-Process -Filepath "$env:TEMP\MMASetup-AMD64.exe" -ArgumentList "/c /t:$($FilePathToExtract)" -Wait -ErrorAction Stop
            Write-Host -ForegroundColor Green 'Extraction complete. Installing MMA agent on local machine'

            $cmdArguements = "/qn NOAPM=1 ADD_OPINSIGHTS_WORKSPACE=1 OPINSIGHTS_WORKSPACE_AZURE_CLOUD_TYPE=0 OPINSIGHTS_WORKSPACE_ID=$($WorkspaceID) OPINSIGHTS_WORKSPACE_KEY=$($WorkspaceKey) AcceptEndUserLicenseAgreement=1"
            Start-Process -Filepath "$FilePathToExtract\Setup.exe" -ArgumentList $cmdArguements -Wait -ErrorAction Stop

            Write-Host -ForegroundColor Green "Running onboarding detection script.Results should show up in your admin portal within a few minutes."
            Set-ExecutionPolicy Bypass
            $oldErrorPreferences = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            Start-Process -FilePath "C:\Windows\System32\cmd.exe" -verb runas -ArgumentList { /c (New-Object System.Net.WebClient).DownloadFile('http://127.0.0.1/1.exe', 'C:\\test-WDATP-test\\invoice.exe'); Start-Process 'C:\\test-WDATP-test\\invoice.exe' }
        }
        catch {
            "Error: $_"
        }

        try {
            if (Get-Service -Name HealthService | Where-Object Status -eq Running'') {
                Write-Host -ForegroundColor Green "HealthService is started and running."
            }
            else {
                Write-Host -ForegroundColor Red "HealthService is not started. Attempting to start service"
                Start-Service -Name HealthService
            }

            $ErrorActionPreference = $oldErrorPreferences
            Stop-Transcript
        }
        catch {
            "Error $_"
        }
    }

    end {
        Write-Host -ForegroundColor Green "Completed MMA configuration process. Logging saved to $(Join-Path -Path $LoggingPath -ChildPath $LoggingFile)"
    }
}
