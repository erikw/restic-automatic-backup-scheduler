# Install restic scheduled tasks.
# Test run the installed actions by opening the app "Task Scheduler" and go to "Task Scheduler Library" and right clicking on the new tasks > run.
# Reference: https://blogs.technet.microsoft.com/heyscriptingguy/2015/01/13/use-powershell-to-create-scheduled-tasks/
# Reference: https://www.davidjnice.com/cygwin_scheduled_tasks.html


# Install restic_backup.sh
$action = New-ScheduledTaskAction -Execute 'C:\Program Files\Git\git-bash.exe' -Argument '-l -c "/c$INSTALL_PREFIX/bin/restic_backup.sh"'
$trigger =  New-ScheduledTaskTrigger -Daily -At 8pm
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "restic_backup" -Description "Daily backup to B2 with restic."



# Install restic_check.sh
$action = New-ScheduledTaskAction -Execute 'C:\Program Files\Git\git-bash.exe' -Argument '-l -c "/c$INSTALL_PREFIX/bin/restic_check.sh"'
$trigger =  New-ScheduledTaskTrigger  -Weekly -WeeksInterval 4 -DaysOfWeek Sunday -At 7pm -RandomDelay 128
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "restic_check" -Description "Check B2 backups with restic."
