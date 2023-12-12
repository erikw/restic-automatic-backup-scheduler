#!/usr/bin/env pwsh
# Install restic scheduled tasks.
# Test run the installed actions by
#   1. open the app "Task Scheduler" (taskschd.msc)
#   2. go to the local "Task Scheduler Library"
#   3. right click on the new tasks  and click "run".
# Reference: https://blogs.technet.microsoft.com/heyscriptingguy/2015/01/13/use-powershell-to-create-scheduled-tasks/
# Reference: https://www.davidjnice.com/cygwin_scheduled_tasks.html


# Install restic_backup.sh
$action = New-ScheduledTaskAction -Execute "$(scoop prefix git)\git-bash.exe" -Argument '-l -c "source {{ INSTALL_PREFIX }}/etc/restic/default.env.sh && {{ INSTALL_PREFIX }}/bin/restic_backup.sh"'
$trigger =  New-ScheduledTaskTrigger -Daily -At 7pm
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "restic_backup" -Description "Daily backup to B2 with restic."

# Install restic_check.sh
$action = New-ScheduledTaskAction -Execute "$(scoop prefix git)\git-bash.exe" -Argument '-l -c "source {{ INSTALL_PREFIX }}/etc/restic/default.env.sh && {{ INSTALL_PREFIX }}/bin/restic_check.sh"'
$trigger =  New-ScheduledTaskTrigger  -Weekly -WeeksInterval 4 -DaysOfWeek Sunday -At 8pm -RandomDelay 128
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "restic_check" -Description "Check B2 backups with restic."
