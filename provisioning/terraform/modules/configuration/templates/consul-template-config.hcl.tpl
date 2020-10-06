consul {
  address = "${consul_address}"
  token = "${consul_template_token}"

  retry {
    enabled = true
    attempts = 12
    backoff = "250ms"
    max_backoff = "1m"
  }

  ssl {
    enabled = true
    verify = true
  }
}

reload_signal = "SIGHUP"
kill_signal = "SIGINT"
max_stale = "10m"
block_query_wait = "60s"
log_level = "warn"

wait {
  min = "5s"
  max = "10s"
}
