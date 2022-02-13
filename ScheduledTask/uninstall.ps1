#!/usr/bin/env pwsh
# Uninstall restic scheduled tasks.

Unregister-ScheduledTask -TaskName "restic_backup" -Confirm:$false
Unregister-ScheduledTask -TaskName "restic_check" -Confirm:$false
