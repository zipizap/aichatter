#!/usr/bin/env bash
# Paulo Aleixo Campos
__dir="$(cd "$(dirname $(readlink -f "${BASH_SOURCE[0]}"))" && pwd)"
function shw_info { echo -e '\033[1;34m'"$1"'\033[0m'; }
function error { echo "ERROR in ${1}"; exit 99; }
#exec > >(tee -i /tmp/$(date +%Y%m%d%H%M%S.%N)__$(basename $0).log ) 2>&1
PS4='████████████████████████${BASH_SOURCE}@${FUNCNAME[0]:-}[${LINENO}]>  '
set -o errexit; trap 'error $LINENO' ERR
#set +o errexit; trap - ERR
set -o pipefail
set -o nounset
#[[ "${DEBUGBASHXTRACE:-}" ]] && set -o xtrace


show_usage_and_exit() {
cat <<EOT
USAGE:

  # Create new dir and fill with skeleton-struct
  mkdir myprog && cd myprog 
  aichatter.sh new                                 # cp -rv "${__dir}/skeleton/* . && git init .

  #### Iteractive workflow:
  vi QUESTION.current.txt
  aichatter.sh QUESTION.current.txt [--dont-run]   # pre git add&&commit, question>response:save to file, [go module update, go run]
  # manually refine/edit files (Ctrl-Shift-G + ,) and then:
  git add . && git commit -m 'answer and refinements'
  # repeat again for next-iteration



  # QUESTION.current.txt example:
----- begin QUESTION.current.txt -----

# lines starting with # are stripped out (not sent)
print seconds since midnight
>>>> insert-here: cat main.go
>>>> insert-existing-file-contents-here: another.go
>>>> response-save-append-to-file: main.go  

----- end QUESTION.current.txt -----



EOT
exit 1
}

parse_arguments_and_flags() {
  # Parse arguments
  [[ $# -eq 0 ]] && show_usage_and_exit
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
      new)
        CLI_ARG_CMD="new"
        shift # remove the argument
        ;;
      --dont-run)
        CLI_FLAG_DONT_RUN=true
        shift # remove the flag
        ;;
      *)
        if [ -e "$1" ]; then
          CLI_ARG_QUESTION_FILE="$1"
        else
          
          echo "Error: File does not exist."
          show_usage_and_exit
        fi
        shift # remove the file
        ;;
    esac
  done  
}

command_new() {
  local GOLANG_SKELETON_DIR="/t/Seafile/Seafile/SharedUnsec/Refs/go/cliapp_boilerplate"
  local AICHATTER_SKELETON_DIR="${__dir}/aichatter_skeleton"
  cp -r "${GOLANG_SKELETON_DIR}"/* .
  cp -r "${AICHATTER_SKELETON_DIR}"/* .
  git init .
}

command_questionfile() {
  local TMP_QUESTION_FILE=$(mktemp)
  local TMP_RESPONSE_FILE=$(mktemp)

  git add . && git commit -m "+ pre $YYYYMMDDhhmmss" || true

  
  # remove comments
  cat "${QUESTION_FILE}" | egrep -v '^#' > "${TMP_QUESTION_FILE}"

  # process >>>> insert-here: cat filea.go | grep -v 'bla bla'
  while cat "${TMP_QUESTION_FILE}" | egrep -n '^>>>> insert-here:' | cut -d: -f1 | head -1 &>/dev/null
  do
    local a_insert_here_cmd_ln=$(cat "${TMP_QUESTION_FILE}" | egrep -n '^>>>> insert-here:' | cut -d: -f1 | head -1)
    a_insert_here_cmd=$(sed -n "${a_insert_here_cmd_ln}p" "${TMP_QUESTION_FILE}" | cut -d: -f2- )
      # "cat filea.go | grep -v 'bla bla'"
    local a_insert_here_cmd_output_file=$(mktemp)
    bash -c "${a_insert_here_cmd}" &> "${a_insert_here_cmd_output_file}" || true
    sed -e "${a_insert_here_cmd_ln}{r ${a_insert_here_cmd_output_file}" -e 'd}' -i "${TMP_QUESTION_FILE}"
  done
  
  # process >>>> response-save-append-to-file: fileb.go
  for a_save_file in $(cat "${TMP_QUESTION_FILE}" | egrep '^>>>> response-save-append-to-file: ' | awk '{ print $3}' )
  do
    # a_save_file=fileb.go
    sed -e "/^>>>> response-save-append-to-file: ${a_save_file//\//\\/}/d" -i "${TMP_QUESTION_FILE}"
    RESPONSE_APPEND_FILE=$a_save_file
  done
  
  echo "" >> "${QUESTION_HISTORY_FILE}"
  echo "=====================================" >> "${QUESTION_HISTORY_FILE}"
  echo "" >> "${QUESTION_HISTORY_FILE}"
  cat "${QUESTION_FILE}" >> "${QUESTION_HISTORY_FILE}" 

  export AICHAT_CONFIG_DIR="${__dir}/config_aichat"
  aichat \
    -r "${PROMPT}" \
    "$(cat ${TMP_QUESTION_FILE})" \
  | tee "${TMP_RESPONSE_FILE}"


  # clean unwanted header/footer that appear sometimes
  # ------- start-of-file -------
  # ...                       || unwanted header
  # ```?go                    ||
  # ... code ...
  # ```                          || unwanted footer
  # ...                          || 
  # ------- end of file -------
  if egrep '^```' "${TMP_RESPONSE_FILE}" &>/dev/null
  then 
    local start_line=$(grep -n -m 1 '^```' ${TMP_RESPONSE_FILE} | cut -f1 -d:)
    start_line=$(( start_line + 1 ))
    local end_line=$(grep -n '^```' ${TMP_RESPONSE_FILE} | tail -n 1 | cut -f1 -d:)
    end_line=$(( end_line - 1 ))
    sed -n "${start_line},${end_line}p" -i "${TMP_RESPONSE_FILE}"
  fi

  # # other times the code-fences in first-and-last-line appear, and need to be removed
  # sed '1{/^```/d;}; ${/^```/d;}' -i "${TMP_RESPONSE_FILE}"


  bat \
    --paging never \
    --language go \
    "${TMP_RESPONSE_FILE}"

  if [[ "${RESPONSE_APPEND_FILE}" != "tbd" ]]
  then
    cat "${TMP_RESPONSE_FILE}" >> "${RESPONSE_APPEND_FILE}"
  else
    cat "${TMP_RESPONSE_FILE}" > main.go
  fi

  if [[ "${CLI_FLAG_DONT_RUN}" == "false" ]]
  then
    ./go_mod_and_run.sh
  fi

}

main() {
  # PROMPT + QUESTION => RESPONSE
  CLI_ARG_CMD=none
    # none or new
  CLI_ARG_QUESTION_FILE=tbd
    # tbd or myfile.txt
  CLI_FLAG_DONT_RUN=false
  
  parse_arguments_and_flags "${@}"

  YYYYMMDDhhmmss=$(date +%Y%m%d%H%M%S)
  QUESTION_FILE="${CLI_ARG_QUESTION_FILE}"
    # myfile.txt
  QUESTION_HISTORY_FILE=QUESTION.history.txt
  RESPONSE_APPEND_FILE=tbd
  PROMPT=rawcodegolang

  # aichatter.sh new
  if [[ "${CLI_ARG_CMD}" == "new" ]]
  then
    command_new
  elif [[ "${CLI_ARG_CMD}" == "none" ]] &&\
       [[ "${CLI_ARG_QUESTION_FILE}" != "tbd" ]]
  then
    command_questionfile
  fi 


}
main "${@}"
