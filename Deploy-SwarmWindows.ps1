# Deploy-SwarmWindows.ps1
# Script PowerShell para build e push da imagem Docker do Windows para Linux Manager
# Uso: .\Deploy-SwarmWindows.ps1 -Action build -ManagerIP 192.168.1.80

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('build', 'push', 'deploy', 'logs', 'status', 'remove')]
    [string]$Action,
    
    [string]$ManagerIP = "192.168.1.80",
    [string]$ManagerSSHUser = "root",
    [string]$Registry = "",  # e.g. "myregistry.com" ou "registry.company.local:5000"
    [string]$ImageName = "morea-ds-web",
    [string]$ImageTag = "latest",
    [string]$ProjectPath = (Get-Location)
)

function Build-Image {
    Write-Host "=== Building Docker image (Windows) ===" -ForegroundColor Green
    docker build -t ${ImageName}:${ImageTag} .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker build failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Image built: ${ImageName}:${ImageTag}" -ForegroundColor Green
}

function Push-Image {
    if ($Registry -eq "") {
        Write-Host "Error: Registry not specified. Use -Registry parameter" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "=== Pushing image to registry ===" -ForegroundColor Green
    $FullImageName = "${Registry}/${ImageName}:${ImageTag}"
    
    docker tag ${ImageName}:${ImageTag} $FullImageName
    docker push $FullImageName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Docker push failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "✓ Image pushed: $FullImageName" -ForegroundColor Green
}

function Deploy-Stack {
    Write-Host "=== Deploying to Swarm Manager ===" -ForegroundColor Green
    
    # Verificar .env
    if (!(Test-Path ".env")) {
        Write-Host "Error: .env not found. Copy from .env.swarm and configure." -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Copying .env to manager..."
    scp -o "StrictHostKeyChecking=no" ".env" "${ManagerSSHUser}@${ManagerIP}:/tmp/.env"
    
    Write-Host "Deploying stack..."
    ssh -o "StrictHostKeyChecking=no" "${ManagerSSHUser}@${ManagerIP}" `
        "cd /path/to/morea-ds-web && docker stack deploy -c docker-stack.yml morea"
    
    # Alternativa (se caminho for diferente):
    # Edite o path acima ou defina um env var no manager
    
    Write-Host "✓ Stack deployment initiated" -ForegroundColor Green
    Write-Host "Check status with: $0 -Action status" -ForegroundColor Cyan
}

function Get-StackStatus {
    Write-Host "=== Stack Status ===" -ForegroundColor Green
    ssh -o "StrictHostKeyChecking=no" "${ManagerSSHUser}@${ManagerIP}" `
        "docker stack ps morea && echo '' && docker service ls | grep morea"
}

function Get-ServiceLogs {
    Write-Host "=== Service Logs ===" -ForegroundColor Green
    ssh -o "StrictHostKeyChecking=no" "${ManagerSSHUser}@${ManagerIP}" `
        "docker service logs morea_web -f"
}

function Remove-Stack {
    Write-Host "=== Removing Stack ===" -ForegroundColor Yellow
    $confirm = Read-Host "Are you sure? (yes/no)"
    if ($confirm -eq "yes") {
        ssh -o "StrictHostKeyChecking=no" "${ManagerSSHUser}@${ManagerIP}" `
            "docker stack rm morea"
        Write-Host "✓ Stack removed" -ForegroundColor Green
    }
}

# Main
Write-Host "Morea Swarm Deployment Tool (Windows → Linux)" -ForegroundColor Cyan
Write-Host "Manager: $ManagerIP | Image: $ImageName:$ImageTag" -ForegroundColor Gray

switch ($Action) {
    "build" { Build-Image }
    "push" { Build-Image; Push-Image }
    "deploy" { Deploy-Stack }
    "status" { Get-StackStatus }
    "logs" { Get-ServiceLogs }
    "remove" { Remove-Stack }
    default { Write-Host "Unknown action: $Action" -ForegroundColor Red; exit 1 }
}

Write-Host "Done." -ForegroundColor Green
