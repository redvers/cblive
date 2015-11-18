use Amnesia
defdatabase Cblclient.Proccache do
  ## Following table used only to track if new events need to bee processed
  deftable(Counts, [:guid, :last_update, :modload, :crossproc, :filemod, :regmod, :emet, :netconn, :childproc, :terminated], type: :set)
  deftable(Summary, [:unique_id, :comms_ip, :modload_count, :childproc_count, :last_update, :username, :group,
                     :hostname, :parent_unique_id, :netconn_count, :parent_pid, :start,
                     :regmod_count, :process_pid, :id, :watchlists, :os_type, :process_md5,
                     :cmdline, :host_type, :sensor_id, :path, :crossproc_count, :segment_id,
                     :filemod_count, :parent_md5, :interface_ip, :parent_name, 
                     :process_name], type: :set)
  deftable(Full, [:unique_id, :modload_complete, :childproc_complete, :netconn_complete, :regmod_complete,
                  :crossproc_complete, :filemod_complete, :binaries], type: :set)


  deftable(Filemod, [:unique_id, :operation, :eventtime, :filepath, :md5, :filetype, :tamper], type: :bag)
  deftable(Netconn, [:unique_id, :direction, :timestamp, :remote_ip, :remote_port, :local_ip, :local_port, :proto, :domain], type: :bag)


  ## Table used to keep date + time
  deftable(Pollstate, [:id, :lastcheck], type: :set)

  ## Table of Sensors...
  deftable(Sensor, [:id, :boot_id, :build_id, :build_version_string, :clock_delta, :computer_dns_name, :computer_name, :computer_sid, :cookie, :display, :emet_dump_flags, :emet_exploit_action, :emet_is_gpo, :emet_process_count, :emet_report_setting, :emet_telemetry_path, :emet_version, :event_log_flush_time, :group_id, :is_isolating, :last_checkin_time, :last_update, :license_expiration, :network_adapters, :network_isolation_enabled, :next_checkin_time, :node_id, :notes, :num_eventlog_bytes, :num_storefiles_bytes, :os_environment_display_string, :os_environment_id, :os_type, :parity_host_id, :physical_memory_size, :power_state, :registration_time, :restart_queued, :sensor_health_message, :sensor_health_status, :sensor_uptime, :shard_id, :status, :supports_2nd_gen_modloads, :supports_cblr, :supports_isolation, :systemvolume_free_size, :systemvolume_total_size, :uninstall, :uninstalled, :uptime], type: :set)
end
