#!/bin/bash

echo "$1" > auth.txt
gh auth login --with-token < auth.txt

# Register patterns
/patterns.sh

echo "============================================================================================"
echo "Scan patterns:"
echo "============================================================================================"
git secrets --list --global

echo "============================================================================================"
echo "Excluded patterns:"
echo "============================================================================================"
cat /.gitallowed
echo "============================================================================================"
echo "Output runs with exceptions found:"
echo "============================================================================================"

repo="$2"
run_count=$3
max_proc_count=4
log_file=exceptions_search.txt


# Collect ids of workflow runs
declare -a run_ids=$(gh run list --repo "$repo" --limit $run_count --json databaseId,status --jq '.[] | select(.status =="completed").databaseId')
touch "$log_file"

run_for_each() {
  local each=$@

  # Collect run logs and remove null
  log_out=$(gh run view $each --repo "$repo" --log 2>/dev/null | sed 's/\x0//g')

  # Identify potential exceptions
  echo $log_out | git secrets --scan - 2>/dev/null
  status=$?
  if (($status != 0));
  then
    # Collect run details if run exception found
    exception=$(gh run view $each --repo "$repo" --json name,createdAt,databaseId,url,updatedAt,headBranch 2>/dev/null);
    echo $exception >>"$log_file"
  fi
}

# Make visible to subprocesses
export -f run_for_each
export log_file
export repo

parallel -0 --jobs $max_proc_count run_for_each ::: $run_ids

json_out=$(jq -n '.exceptions |= [inputs]' "$log_file")

# Make output friendly
json_out="${json_out//'%'/'%25'}"
json_out="${json_out//$'\n'/'%0A'}"
json_out="${json_out//$'\r'/'%0D'}"
echo "::set-output name=exceptions::$json_out"

rm "$log_file" 
