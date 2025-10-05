# Installs all VirtIO drivers
$drivers = Get-ChildItem -Path D:\ -Recurse -Include *.inf
foreach ($driver in $drivers) {
    pnputil.exe /add-driver $driver.FullName /install
}

