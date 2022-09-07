#!/bin/bash

ls
printenv
# Init
repo="$2"
run_count=$3
min_days_old=$4
max_days_old=$5
fail_on_leak=$8
max_proc_count=32
log_file=exceptions_search.txt

# Set defaults
if [[ -z $min_days_old ]]; then
  min_days_old="0"
  echo "min_days_old: $min_days_old"
fi

if [[ -z $max_days_old ]]; then
  max_days_old="3"
  echo "max_days_old: $max_days_old"
fi

if [[ -z $fail_on_leak ]]; then
  fail_on_leak=true
  echo "fail_on_leak: $fail_on_leak"
fi

# If file path error, use default patterns
if cp "$6" /patterns.txt; then
  # Register patterns
  grep -v -E '(#.*$)|(^$)' /patterns.txt >/clean_patterns.txt
  while read line; do
    if [[ "$line" != "#*" ]]; then
      git secrets $line --global
    fi
  done </clean_patterns.txt
else
  git secrets --register-azure --global
  git secrets --register-aws --global
  git secrets --register-gcp --global
fi

cp "$7" /.gitallowed

# GitHub auth
echo "$1" >auth.txt
gh auth login --with-token <auth.txt
if [[ $? -ne 0 ]]; then
  exit 1
fi

git config --global --add safe.directory /github/workspace
echo "Repo: $repo"
echo "============================================================================================"
echo "Scan patterns:"
echo "============================================================================================"
git secrets --list --global
echo "============================================================================================"
echo "Excluded patterns:"
echo "============================================================================================"
cat /.gitallowed
echo "============================================================================================"

# Collect up to 400/day id runs
run_list_limit=$(($max_days_old * 400))

echo "Raw run list limited to: $run_list_limit"


git_hash=$(git rev-parse --short "$GITHUB_SHA")
git_branch=${GITHUB_REF#refs/heads/}

#echo "Runs to scan: $run_count"
#echo $run_ids_limited

touch "$log_file"



  # Collect run logs and remove null
  #log_out=$(gh run view $each --repo "$repo" --log 2>/dev/null | sed 's/\x0//g')
  #if [[ $? -ne 0 ]]; then
  #  exit 1
  #fi

  #echo "log_out -| $log_out"
  # Identify potential exceptions
  scan_out=$(git secrets --scan)

  echo "scan_out | $scan_out"
  status=$?

  # If exception, add to array of details
  if (($status != 0)); then
    raw_log_full=$(echo "$scan_out" | grep '(standard input)')
    
    #echo "scan_out -| $scan_out"
    #echo "raw_log_full -| $raw_log_full"
    
    exception_line=$(echo "$raw_log_full" | awk -F '\t' '{print $1$2}' | sed 's/[^a-zA-Z0-9]/_/g' | sed 's/.*/"&",/')
    
    #echo "exception_line -| $exception_line"
    
     
    exception=$(gh run view $each --repo "$repo" --json name,createdAt,databaseId,url,updatedAt,headBranch 2>/dev/null)
    #echo "exception -| $exception"
    
    if [[ $? -ne 0 ]]; then
      exit 1
    fi
    exception_with_detail=$(echo $exception | jq '. + {exception_detail: {'"$exception_line"'}}')
    echo $exception_with_detail >>"$log_file"
  fi


# Make visible to subprocesses
export log_file
export repo

#echo "--------------------"
#cat $log_file
#echo "--------------------"
json_out=$(jq -n '.exceptions |= [inputs]' "$log_file")
json_out_length=$(echo $json_out | jq -s '.[].exceptions' | jq length)
echo "$json_out"

# Make output friendly
json_out="${json_out//'%'/'%25'}"
json_out="${json_out//$'\n'/'%0A'}"
json_out="${json_out//$'\r'/'%0D'}"
echo "::set-output name=exceptions::$json_out"
echo "::set-output name=count::$json_out_length"

#rm "$log_file"

if [[ $fail_on_leak = true && json_out_length -gt 0 ]]; then
  echo "Failing since leak!"
  exit 1
fi

#sleep 5m # Waits 5 minutes.
