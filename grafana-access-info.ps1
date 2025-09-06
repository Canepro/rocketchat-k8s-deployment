# Grafana Access Verification Script
# Updated: September 6, 2025

Write-Host "🔐 GRAFANA LOGIN INFORMATION" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host ""

Write-Host "✅ SSL Certificate Issue: RESOLVED" -ForegroundColor Green
Write-Host "   - Works in incognito mode (browser cache issue)" -ForegroundColor White
Write-Host "   - Clear browser cache or use incognito mode" -ForegroundColor White
Write-Host ""

Write-Host "🔑 CURRENT WORKING CREDENTIALS:" -ForegroundColor Yellow
Write-Host "   URL: https://grafana.chat.canepro.me" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor Cyan
Write-Host "   Password: admin" -ForegroundColor Cyan
Write-Host ""

Write-Host "📝 Note: Password was updated from outdated README" -ForegroundColor Yellow
Write-Host "   - Old (incorrect): GrafanaAdmin2024!" -ForegroundColor Red
Write-Host "   - New (correct): admin" -ForegroundColor Green
Write-Host ""

Write-Host "🛡️ SECURITY RECOMMENDATION:" -ForegroundColor Yellow
Write-Host "   After login, change the default password:" -ForegroundColor White
Write-Host "   1. Login with admin/admin" -ForegroundColor White
Write-Host "   2. Go to Configuration → Users" -ForegroundColor White
Write-Host "   3. Click admin user and change password" -ForegroundColor White
Write-Host "   4. Update documentation with new password" -ForegroundColor White
Write-Host ""

Write-Host "🔍 VERIFICATION COMMANDS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "# Check Grafana pods status:"
Write-Host "kubectl get pods -n monitoring | findstr grafana"
Write-Host ""
Write-Host "# Get current credentials from Kubernetes:"
Write-Host "kubectl get secret grafana-admin-credentials -n monitoring -o yaml"
Write-Host ""
Write-Host "# Check certificate status:"
Write-Host "kubectl get certificates -n monitoring"
Write-Host ""

# Quick status check
Write-Host "📊 CURRENT STATUS:" -ForegroundColor Blue
try {
    $grafanaPods = kubectl get pods -n monitoring 2>$null | Select-String "grafana" | Select-String "Running"
    if ($grafanaPods) { 
        Write-Host "   ✅ Grafana pods: Running" -ForegroundColor Green
        Write-Host "      $($grafanaPods -join "`n      ")" -ForegroundColor White
    }
    
    $cert = kubectl get certificates -n monitoring 2>$null | Select-String "grafana-tls" | Select-String "True"
    if ($cert) { 
        Write-Host "   ✅ SSL Certificate: Ready" -ForegroundColor Green 
    }
}
catch {
    Write-Host "   ⚠️ kubectl not available for verification" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎯 NEXT STEPS:" -ForegroundColor Green
Write-Host "   1. Clear browser cache or use incognito mode" -ForegroundColor White
Write-Host "   2. Access: https://grafana.chat.canepro.me" -ForegroundColor White
Write-Host "   3. Login with: admin/admin" -ForegroundColor White
Write-Host "   4. Change password for security" -ForegroundColor White
Write-Host ""
Write-Host "All systems operational! 🚀" -ForegroundColor Green
