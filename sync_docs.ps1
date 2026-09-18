# Script Kiem tra Dong bo Tai lieu giua cac Du an THACO EVSE
Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "    KIEM TRA TRANG THAI DONG BO TAI LIEU HE THONG THACO EVSE    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$repos = @(
    @{ Name = "EVSE_H743";      Path = "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743" },
    @{ Name = "F429_OCPP1.6J";  Path = "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\F429_OCPP1.6J" },
    @{ Name = "esp32_ocpp_v2";  Path = "D:\DuAn\10.ViDieuKhien\esp32_ocpp_v2" },
    @{ Name = "csms_evse";      Path = "D:\DuAn\1.EVSE\csms_evse" },
    @{ Name = "hmi_evse";       Path = "D:\DuAn\1.EVSE\hmi_evse" },
    @{ Name = "THACO_Charge";   Path = "D:\DuAn\1.EVSE\THACO_Charge" }
)

foreach ($repo in $repos) {
    if (Test-Path $repo.Path) {
        $branch = git -C $repo.Path branch --show-current 2>$null
        $commit = git -C $repo.Path log -1 --format="%h - %s (%cr)" 2>$null
        $status = git -C $repo.Path status --short 2>$null
        
        Write-Host "[$($repo.Name)]" -ForegroundColor Green
        Write-Host "  Path:   $($repo.Path)"
        Write-Host "  Branch: $branch"
        Write-Host "  Commit: $commit"
        if ($status) {
            Write-Host "  Status: CO THAY DOI CHUA COMMIT!" -ForegroundColor Yellow
        } else {
            Write-Host "  Status: Clean (San sang)" -ForegroundColor Gray
        }
    } else {
        Write-Host "[$($repo.Name)] - KHONG TIM THAY THU MUC!" -ForegroundColor Red
    }
    Write-Host "-----------------------------------------------------------------"
}

Write-Host "`nKiem tra hoan tat. Vui long tuan thu quy che tai DOCS_SYNC_POLICY.md!" -ForegroundColor Cyan
