# VelocityTasks PowerShell Scripts
# Windows-compatible versions of the bash scripts

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output (using Write-Host with colors)
function Write-Red { param($Text) Write-Host $Text -ForegroundColor Red }
function Write-Green { param($Text) Write-Host $Text -ForegroundColor Green }
function Write-Yellow { param($Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Blue { param($Text) Write-Host $Text -ForegroundColor Blue }

# Configuration
$APP_NAME = "velocitytasks"
$VERSION = "1.0.0"
$BUILD_DIR = "build"

# Function to build the application
function Build-Application {
    Write-Blue "🔨 Building VelocityTasks for Windows..."
    
    # Create build directory
    if (!(Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR -Force | Out-Null
    }
    
    # Build Windows binary
    $env:GOOS = "windows"
    $env:GOARCH = "amd64"
    
    $BuildTime = Get-Date -Format "2006-01-02T15:04:05Z"
    $GitCommit = try { git rev-parse HEAD 2>$null } catch { "unknown" }
    
    $LDFlags = "-X main.Version=$VERSION -X main.BuildTime=$BuildTime -X main.GitCommit=$GitCommit"
    
    go build -ldflags $LDFlags -o "$BUILD_DIR\$APP_NAME-windows-amd64.exe" main.go
    
    if (Test-Path "$BUILD_DIR\$APP_NAME-windows-amd64.exe") {
        Write-Green "✅ Windows binary built successfully"
    } else {
        Write-Red "❌ Failed to build Windows binary"
        exit 1
    }
}

# Function to test the application
function Test-Application {
    Write-Blue "🧪 Testing VelocityTasks..."
    
    # Check if go is available
    try {
        go version | Out-Null
    } catch {
        Write-Red "❌ Go not found. Please install Go."
        exit 1
    }
    
    # Run Go tests if available
    if (Test-Path "tests") {
        Write-Yellow "Running Go tests..."
        go test ./tests/... -v
        Write-Green "✅ Go tests completed"
    }
    
    # Build test binary
    Write-Yellow "Building test binary..."
    go build -o "$APP_NAME-test.exe" main.go
    
    if (!(Test-Path "$APP_NAME-test.exe")) {
        Write-Red "❌ Failed to build test binary"
        exit 1
    }
    
    # Start test server
    Write-Yellow "Starting test server on port 8081..."
    
    $env:PORT = "8081"
    $env:HOST = "localhost"
    $env:STATIC_DIR = "web"
    $env:LOG_LEVEL = "debug"
    
    $ServerJob = Start-Job -ScriptBlock {
        param($ExePath)
        & $ExePath
    } -ArgumentList (Resolve-Path "$APP_NAME-test.exe")
    
    # Wait for server to start
    $Attempts = 0
    $MaxAttempts = 30
    
    while ($Attempts -lt $MaxAttempts) {
        try {
            $Response = Invoke-WebRequest -Uri "http://localhost:8081/health" -UseBasicParsing -TimeoutSec 1
            if ($Response.StatusCode -eq 200) {
                Write-Green "✅ Test server started successfully"
                break
            }
        } catch {
            # Server not ready yet
        }
        
        $Attempts++
        Start-Sleep -Seconds 1
    }
    
    if ($Attempts -eq $MaxAttempts) {
        Write-Red "❌ Failed to start test server"
        Stop-Job $ServerJob -Force
        Remove-Job $ServerJob -Force
        Remove-Item "$APP_NAME-test.exe" -Force
        exit 1
    }
    
    # Test endpoints
    try {
        Write-Yellow "Testing health endpoint..."
        $Response = Invoke-WebRequest -Uri "http://localhost:8081/health" -UseBasicParsing
        if ($Response.StatusCode -eq 200) {
            Write-Green "✅ Health endpoint working"
        }
        
        Write-Yellow "Testing static files..."
        $Response = Invoke-WebRequest -Uri "http://localhost:8081/" -UseBasicParsing
        if ($Response.StatusCode -eq 200) {
            Write-Green "✅ Static files served successfully"
        }
        
        Write-Yellow "Testing API endpoints..."
        $TaskData = @{
            title = "Test Task"
            description = "This is a test task"
            priority = "medium"
            status = "pending"
        } | ConvertTo-Json
        
        $Response = Invoke-WebRequest -Uri "http://localhost:8081/api/tasks" -Method POST -Body $TaskData -ContentType "application/json" -UseBasicParsing
        if ($Response.StatusCode -eq 201) {
            Write-Green "✅ API endpoints working"
        }
        
        Write-Green "🎉 All tests passed!"
        
    } catch {
        Write-Red "❌ Test failed: $($_.Exception.Message)"
    } finally {
        # Cleanup
        Stop-Job $ServerJob -Force
        Remove-Job $ServerJob -Force
        Remove-Item "$APP_NAME-test.exe" -Force
    }
}

# Function to run the application
function Start-Application {
    Write-Blue "🚀 Starting VelocityTasks..."
    
    if (Test-Path "$BUILD_DIR\$APP_NAME-windows-amd64.exe") {
        & "$BUILD_DIR\$APP_NAME-windows-amd64.exe"
    } elseif (Test-Path "main.go") {
        go run main.go
    } else {
        Write-Red "❌ No executable found. Run build first."
        exit 1
    }
}

# Function to deploy locally
function Deploy-Local {
    Write-Blue "📦 Deploying VelocityTasks locally..."
    
    # Create deployment directory
    $DeployDir = "deploy"
    if (!(Test-Path $DeployDir)) {
        New-Item -ItemType Directory -Path $DeployDir -Force | Out-Null
    }
    
    # Copy files
    if (Test-Path "$BUILD_DIR\$APP_NAME-windows-amd64.exe") {
        Copy-Item "$BUILD_DIR\$APP_NAME-windows-amd64.exe" "$DeployDir\$APP_NAME.exe"
    } else {
        Write-Red "❌ Windows binary not found. Run build first."
        exit 1
    }
    
    Copy-Item -Recurse web "$DeployDir\" -Force
    Copy-Item config.yaml "$DeployDir\" -Force
    
    Write-Green "✅ Local deployment ready in $DeployDir\"
    Write-Green "Run: cd $DeployDir && .\$APP_NAME.exe"
}

# Function to show usage
function Show-Usage {
    Write-Blue "VelocityTasks PowerShell Scripts"
    Write-Blue "================================"
    Write-Host ""
    Write-Host "Usage: .\scripts.ps1 [command]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  build      - Build the application"
    Write-Host "  test       - Run tests"
    Write-Host "  start      - Start the application"
    Write-Host "  deploy     - Deploy locally"
    Write-Host "  help       - Show this help"
    Write-Host ""
}

# Main script logic
param(
    [Parameter(Position=0)]
    [string]$Command = "help"
)

switch ($Command.ToLower()) {
    "build" { Build-Application }
    "test" { Test-Application }
    "start" { Start-Application }
    "deploy" { Deploy-Local }
    "help" { Show-Usage }
    default { Show-Usage }
}
