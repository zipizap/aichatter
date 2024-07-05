aiconsume() {
  cat a.txt \
  | aichat \
    --model gpt-3.5-turbo \
    'criticize and argument forward and against the following reasoning. Do an extensive response' \
  > /dev/null
}

main() {
  # a.txt contains ~ 3k input tokens
  # 1€ ~ 700k input tokens (gpt-3.5-turbo) ~ 200 a.txt requests
  # rate-limit 90k-token/min == 30 a.txt request/min
  #
  # So to consume around 1€, we should use:
  #    total_num_requests=200
  #    paralel_max = 30 a.txt request/min ideally (but in reality it hits rate-limit)
  #                = 20 in reality to avoid rate-limit
  #    and will take around 200/20 ~ 10min to execute


  local total_num_requests=200
  local paralel_max=20

  local paralel_num=0
  echo '123456789012345678901234567890'
  echo '0        1         2         3'
  for i in $(seq 1 $total_num_requests)
  do 
    echo -n "."
    aiconsume &

    paralel_num=$((paralel_num + 1))
    if [[ "${paralel_num}" == "${paralel_max}" ]]; then 
      paralel_num=0 
      wait  
      echo "  [$i]"
      # avoid hitting token-rate-limit 90k/min
      sleep 60 
    fi

  done
}
main
