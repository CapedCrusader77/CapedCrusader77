try {
    $user = Invoke-RestMethod -Uri "https://api.github.com/users/CapedCrusader77" -Headers @{ "User-Agent" = "PowerShell" }
    Write-Host "=== USER ==="
    $user | Select-Object login, name, bio, public_repos, followers, following, created_at | Format-List

    Write-Host "=== REPOSITORIES ==="
    $repos = Invoke-RestMethod -Uri "https://api.github.com/users/CapedCrusader77/repos?per_page=100&sort=updated" -Headers @{ "User-Agent" = "PowerShell" }
    $repos | Select-Object name, stargazers_count, forks_count, language, description, updated_at | Format-Table -AutoSize

    Write-Host "=== TOTAL STARS ==="
    $totalStars = ($repos | Measure-Object -Property stargazers_count -Sum).Sum
    Write-Host "Total Stars: $totalStars"

    Write-Host "=== LANGUAGE BREAKDOWN ==="
    $langGroups = $repos | Where-Object { $_.language } | Group-Object language | Select-Object Name, Count | Sort-Object Count -Descending
    $langGroups | Format-Table -AutoSize

    Write-Host "=== RECENT EVENTS ==="
    $events = Invoke-RestMethod -Uri "https://api.github.com/users/CapedCrusader77/events?per_page=30" -Headers @{ "User-Agent" = "PowerShell" }
    $events | Select-Object type, @{n='repo';e={$_.repo.name}}, created_at | Select-Object -First 15 | Format-Table -AutoSize

    # Save to JSON for exact processing
    $data = @{
        user = $user
        repos = $repos
        totalStars = $totalStars
        languages = $langGroups
        events = $events
    }
    $data | ConvertTo-Json -Depth 5 | Set-Content -Path "e:\Projects\Readme\real_github_data.json" -Encoding UTF8
    Write-Host "Successfully saved real data to real_github_data.json"
} catch {
    Write-Error $_
}
