# PowerShell Build Script for Morea Docker Image
# Usage (from Windows workstation):
#   .\build-image.ps1 -ManagerIP "192.168.1.80" -Registry "192.168.1.80:5000" -Tag "latest"
# or to build+push via SSH on manager:
#   .\build-image.ps1 -ManagerIP "192.168.1.80" -UseSSH -Registry "192.168.1.80:5000"

param(
    [Parameter(Mandatory=$false)]
    [string]$ManagerIP = "192.168.1.80",
    
    [Parameter(Mandatory=$false)]
    [string]$Registry = "192.168.1.80:5000",
    
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$SSHUser = "pi",
    
    [Parameter(Mandatory=$false)]
    [bool]$UseSSH = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$RepoPath = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$Dockerfile = "Dockerfile"
)

# Colors
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Reset = "`e[0m"

Write-Host "${Yellow}=== Morea Docker Build & Push ===${Reset}" -ForegroundColor Green
Write-Host "Manager IP: $ManagerIP"
Write-Host "Registry: $Registry"
Write-Host "Tag: $Tag"
Write-Host "Use SSH: $UseSSH"
Write-Host ""

# Validate repo path
if (-not (Test-Path "$RepoPath/$Dockerfile")) {
    Write-Host "${Red}Error: Dockerfile not found at $RepoPath/$Dockerfile${Reset}" -ForegroundColor Red
    exit 1
}

$ImageName = "morea-app"
$FullImage = if ($Registry) { "$Registry/$ImageName`:$Tag" } else { "$ImageName`:$Tag" }

if ($UseSSH) {
    Write-Host "${Yellow}[1/2] Connecting to manager and building image via SSH...${Reset}" -ForegroundColor Yellow
    
    # Build via SSH on the manager
    $BuildCmd = @"
cd /home/$SSHUser/morea && \
docker build -t $FullImage -f $Dockerfile . && \
echo 'Build complete, pushing to registry...' && \
docker push $FullImage || echo 'Push skipped or failed (registry may not be running)'
"@
    
    try {
        ssh "$SSHUser@$ManagerIP" $BuildCmd
        Write-Host "${Green}✓ Build and push complete${Reset}" -ForegroundColor Green
    } catch {
        Write-Host "${Red}✗ SSH command failed${Reset}" -ForegroundColor Red
        Write-Host "Error: $_"
        exit 1
    }
} else {
    Write-Host "${Yellow}[1/1] Building image locally (Windows)...${Reset}" -ForegroundColor Yellow
    Write-Host "Note: This builds for your current platform (likely x86_64). For ARM, use UseSSH=`$true"
    
    # Build locally
    try {
        docker build -t $FullImage -f "$RepoPath/$Dockerfile" $RepoPath
        Write-Host "${Green}✓ Build successful${Reset}" -ForegroundColor Green
        
        if ($Registry) {
            Write-Host "Push to registry manually: docker push $FullImage"
        }
    } catch {
        Write-Host "${Red}✗ Build failed${Reset}" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "${Green}=== Next Steps ===${Reset}" -ForegroundColor Green
Write-Host "1. Ensure docker-stack.yml uses image: $FullImage"
Write-Host "2. Copy docker-stack.yml and .env.swarm to manager (if not already present)"
Write-Host "3. On manager, deploy: docker stack deploy -c docker-stack.yml morea --with-registry-auth"
Write-Host "4. Monitor: docker service ls; docker service ps morea_web"
Write-Host ""
Write-Host "To deploy from this workstation, run:"
Write-Host "  scp .\docker-stack.yml pi@$ManagerIP`:/home/pi/morea/"
Write-Host "  scp .\.env.swarm pi@$ManagerIP`:/home/pi/morea/"
Write-Host "  ssh pi@$ManagerIP docker stack deploy -c /home/pi/morea/docker-stack.yml morea --with-registry-auth"

