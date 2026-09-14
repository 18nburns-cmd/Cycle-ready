do $$
declare existing_job bigint;
begin
  select jobid into existing_job from cron.job
  where jobname = 'cycle-ready-notification-delivery';
  if existing_job is not null then perform cron.unschedule(existing_job); end if;

  perform cron.schedule(
    'cycle-ready-notification-delivery',
    '* * * * *',
    $job$select net.http_post(
        url := 'https://tvqzvuvthpvnzkvikdmy.supabase.co/functions/v1/deliver-notifications',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'x-cycle-ready-scheduler-secret',
          (select decrypted_secret from vault.decrypted_secrets
           where name = 'cycle_ready_scheduler_secret_v1')
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 15000
      );$job$
  );
end;
$$;
